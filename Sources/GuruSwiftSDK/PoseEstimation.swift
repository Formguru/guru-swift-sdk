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


private func preprocessImage(img: CGImage, bbox: [Int]) -> CGImage {
  let bboxStruct = Bbox(x: Int32(bbox[0]), y: Int32(bbox[1]), w: Int32(bbox[2]), h: Int32(bbox[3]), category: 0)
  let ptr = pixelsRGB(img: img)
  let originalImage = RgbImage(rgb: ptr, height: Int32(img.height), width: Int32(img.width))
  let withAlpha = true
  let preprocessed = do_preprocess2(originalImage, bboxStruct, withAlpha)
  var pixelBuffer: CVPixelBuffer?
  CVPixelBufferCreateWithBytes(
    nil,
    Int(preprocessed.image.width),
    Int(preprocessed.image.height),
    kCVPixelFormatType_24RGB,
    preprocessed.image.rgb,
    Int(preprocessed.image.width * 3),
    nil,
    nil,
    nil,
    &pixelBuffer
  )
  let ciContext = CIContext()
  let ciImage = CIImage(cvImageBuffer: pixelBuffer!)
  return ciContext.createCGImage(ciImage, from: ciImage.extent)!
}


private func parseOutput(_ output: MLFeatureProvider, _ preprocessed: ImageFeat, _ img: CGImage) -> [Int : [Float]] {
  var result = Dictionary<Int, [Float]>()
  let keypoints = output.featureValue(for: "keypoints")!.multiArrayValue!
  let scores = output.featureValue(for: "scores")!.multiArrayValue!
  let K = 17
  
  let scale_x = preprocessed.center_scale.scale_x
  let scale_y = preprocessed.center_scale.scale_y
  let sx = (scale_x * 200) / (192/4)
  let sy = (scale_y * 200) / (256/4)
  let cx = preprocessed.center_scale.center_x
  let cy = preprocessed.center_scale.center_y
  
  for k in 0..<K {
    let x = keypoints[[0, k, 0] as [NSNumber]]
    let y = keypoints[[0, k, 1] as [NSNumber]]
    let score = scores[[0, k] as [NSNumber]]
    
    let originalX = (x.floatValue * sx) + cx - ((scale_x * 200) / 2)
    let originalY = (y.floatValue * sy) + cy - ((scale_y * 200) / 2)
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
    NSNumber(value: 3 * 256 * 192),
    NSNumber(value: 256 * 192),
    NSNumber(value: 192),
    NSNumber(value: 1)
  ]
  // TODO: deallocator?
  return try! MLMultiArray(dataPointer: ptr, shape: [1, 3, 256, 192], dataType: .float32, strides: strides)
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


