//
//  PoseEstimation.swift
//  Runner
//
//  Created by Andrew Stahlman on 6/16/22.
//

import Foundation
import CoreML
import Vision
import UIKit
import libgurucv
import ZIPFoundation
import os

@available(iOS 14.0, *)
private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier!,
    category: "PoseEstimation"
)

public enum PoseModelError: Error {
  case downloadFailed
  case compileFailed
}

private let (INPUT_HEIGHT, INPUT_WIDTH) = (256, 192)

private func parseOutput(_ output: MLFeatureProvider, _ preprocessed: ImageFeat, _ img: CGImage) -> [Int : [Float]] {
  var result = Dictionary<Int, [Float]>()
  let keypoints = output.featureValue(for: "keypoints")!.multiArrayValue!
  let scores = output.featureValue(for: "scores")!.multiArrayValue!
  let K = 17
  
  let stdHeight = Float(200.0)
  let scaleY = preprocessed.center_scale.scale_y
  let scaleX = preprocessed.center_scale.scale_x
  let sy = (scaleY * stdHeight) / (Float(INPUT_HEIGHT)/4)
  let sx = (scaleX * stdHeight) / (Float(INPUT_WIDTH)/4)
  let cy = preprocessed.center_scale.center_y
  let cx = preprocessed.center_scale.center_x
  
  for k in 0..<K {
    let x = keypoints[[0, k, 0] as [NSNumber]]
    let y = keypoints[[0, k, 1] as [NSNumber]]
    let score = scores[[0, k] as [NSNumber]]
    
    let originalX = (x.floatValue * sx) + cx - ((scaleX * stdHeight) / 2)
    let originalY = (y.floatValue * sy) + cy - ((scaleY * stdHeight) / 2)
    result[k] = [originalX / Float(img.width), originalY / Float(img.height), score.floatValue]
  }
  return result
}

func inferPose(model: MLModel, img: CGImage, bbox: [Int]) -> Dictionary<Int, [Float]>? {
  let preprocessingStart = CFAbsoluteTimeGetCurrent()
  let ptr = pixelsRGB(img: img)
  defer { ptr.deallocate() }
  let rgbImg = RgbImage(rgb: ptr, height: Int32(img.height), width: Int32(img.width))
  let bboxStruct = Bbox(x: Int32(bbox[0]), y: Int32(bbox[1]), w: Int32(bbox[2]), h: Int32(bbox[3]), category: 0)
  let bboxArr = try! MLMultiArray(shape: [1, 4], dataType: .float32)
  for i in 0..<4 {
    bboxArr[i] = NSNumber(value: bbox[i])
  }
  let withAlpha = true
  let preprocessed = do_preprocess(rgbImg, bboxStruct, withAlpha)
  defer { free(preprocessed.rawValues) }
  
  
  let inferenceStart = CFAbsoluteTimeGetCurrent()
  guard let
          feats = try? MLDictionaryFeatureProvider(dictionary: [
            "image_nchw": imgToMLMultiArray(ptr: preprocessed.rawValues)
          ]),
        let output = try? model.prediction(from: feats) else {
    return nil
  }
  
  let preprocessingMs = 1000 * (inferenceStart - preprocessingStart)
  let inferenceMs = 1000 * (CFAbsoluteTimeGetCurrent() - inferenceStart)
  
  if #available(iOS 14.0, *) {
    logger.trace("Preprocessing: \(preprocessingMs) ms")
    logger.trace("Inference: \(inferenceMs) ms")
  }
  
  return parseOutput(output, preprocessed, img)
}

private func imgToMLMultiArray(ptr: UnsafeMutableRawPointer) -> MLMultiArray {
  let strides = [
    NSNumber(value: 3 * INPUT_HEIGHT * INPUT_WIDTH),
    NSNumber(value: INPUT_HEIGHT * INPUT_WIDTH),
    NSNumber(value: INPUT_WIDTH),
    NSNumber(value: 1)
  ]
  // TODO: deallocator?
  return try! MLMultiArray(dataPointer: ptr, shape: [1, 3, NSNumber(value: INPUT_HEIGHT), NSNumber(value: INPUT_WIDTH)], dataType: .float32, strides: strides)
}

public func pixelsRGB(img: CGImage) -> UnsafeMutablePointer<UInt8> {
  let dataSize = img.width * img.height * 4
  let pixelData = UnsafeMutablePointer<UInt8>.allocate(capacity: dataSize)
  let colorSpace = CGColorSpaceCreateDeviceRGB()
  let context = CGContext(data: pixelData,
                          width: Int(img.width),
                          height: Int(img.height),
                          bitsPerComponent: 8,
                          bytesPerRow: 4 * Int(img.width),
                          space: colorSpace,
                          bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
  context?.draw(img, in: CGRect(x: 0, y: 0, width: img.width, height: img.height))
  return UnsafeMutablePointer<UInt8>(pixelData)
}


