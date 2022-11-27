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

@available(iOS 14.0, *)
var vipnasNew = try! VipnasNoPreprocess(contentsOf: Bundle.module.url(forResource: "VipnasNoPreprocess", withExtension: "mlmodelc")!)

enum PoseModelError: Error {
  case downloadFailed
  case compileFailed
}

func downloadFile(url: URL) async throws -> URL {
  let fm = FileManager.default
  let appSupportUrl = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
  let rootUrl = appSupportUrl.appendingPathComponent("GuruOnDeviceModel")
  try! fm.createDirectory(at: rootUrl, withIntermediateDirectories: true)
  return try await withCheckedThrowingContinuation({ continuation in
    URLSession.shared.downloadTask(with: url, completionHandler: {
      urlOrNil, responseOrNil, errorOrNil in
      if let err = errorOrNil {
        continuation.resume(throwing: err)
      } else if let tmpUrl = urlOrNil {
        let outputUrl = rootUrl.appendingPathComponent(url.lastPathComponent)
        if FileManager.default.fileExists(atPath: outputUrl.path) {
          try! FileManager.default.removeItem(at: outputUrl)
        }
        try! FileManager.default.moveItem(at: tmpUrl, to: outputUrl)
        assert(FileManager.default.fileExists(atPath: outputUrl.path))
        continuation.resume(returning: outputUrl)
      } else {
        continuation.resume(throwing: PoseModelError.downloadFailed)
      }
    }).resume()
  })
}

func fetchModel() async -> Result<URL, PoseModelError> {
  let url = URL(string: "https://formguru-datasets.s3.us-west-2.amazonaws.com/on-device/andrew-temp-test/VipnasNoPreprocess.mlpackage.zip")!
  
  let fm = FileManager()
  let modelZip: URL
  do {
    modelZip = try await downloadFile(url: url)
  } catch {
    return .failure(PoseModelError.downloadFailed)
  }
  assert(fm.fileExists(atPath: modelZip.path))
  let unzipDirectory = try! FileManager.default.url(
    for: .itemReplacementDirectory,
    in: .userDomainMask,
    appropriateFor: modelZip,
    create: true
  )
  try! fm.unzipItem(at: modelZip, to: unzipDirectory)
  let mlpackage = unzipDirectory.appendingPathComponent("VipnasNoPreprocess.mlpackage")
  guard let modelUrl = try? MLModel.compileModel(at: mlpackage) else {
    return .failure(PoseModelError.compileFailed)
  }
  print("Model compiled to \(modelUrl)")
  return .success(modelUrl)
}

func initModel() async -> Result<MLModel, PoseModelError> {
  switch await fetchModel() {
  case .failure(let err):
    return .failure(err)
  case .success(let url):
    if let mlModel = try? MLModel(contentsOf: url) {
      return .success(mlModel)
    } else {
      return .failure(PoseModelError.compileFailed)
    }
  }
}

func preprocessImage(img: CGImage, bbox: [Int]) -> CGImage {
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


func inferPose(model: MLModel, img: CGImage, bbox: [Int]) -> Dictionary<Int, [Float]>? {
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
  let output: MLFeatureProvider
  do {
    let feats = try MLDictionaryFeatureProvider(dictionary: [
      "image_nchw": imgToMLMultiArray(ptr: preprocessed.rawValues)
    ])
    defer { free(preprocessed.rawValues) }
    output = try model.prediction(from: feats)
  } catch {
    return nil
  }
  
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

@available(iOS 14.0, *)
func runVipnasInference(img: RgbImage, bbox: [Int]) -> Dictionary<Int, [Float]> {
  let t1 = CFAbsoluteTimeGetCurrent()
  let bboxStruct = Bbox(x: Int32(bbox[0]), y: Int32(bbox[1]), w: Int32(bbox[2]), h: Int32(bbox[3]), category: 0)
  let bboxArr = try! MLMultiArray(shape: [1, 4], dataType: .float32)
  for i in 0..<4 {
    bboxArr[i] = NSNumber(value: bbox[i])
  }
  
  let withAlpha = true
  let preprocessed = do_preprocess(img, bboxStruct, withAlpha)
  let t2 = CFAbsoluteTimeGetCurrent()
  let preprocessTime = (t2 - t1) * 1000
  print("Preprocess \(preprocessTime) ms")
  
  let vipnasInput = VipnasNoPreprocessInput(
    image_nchw: imgToMLMultiArray(ptr: preprocessed.rawValues)
  )
  let output = try! vipnasNew.prediction(input: vipnasInput)
  free(preprocessed.rawValues)
  // TODO: add back the +/-0.25 px (in heatmap space == 1px in image space)
  // translation from the "coldest" neighbor
  let t3 = CFAbsoluteTimeGetCurrent()
  let predictTime = (t3 - t2) * 1000
  print("Predict time \(predictTime) ms")
  let K = 17
  
  let scale_x = preprocessed.center_scale.scale_x
  let scale_y = preprocessed.center_scale.scale_y
  let sx = (scale_x * 200) / (192/4)
  let sy = (scale_y * 200) / (256/4)
  let cx = preprocessed.center_scale.center_x
  let cy = preprocessed.center_scale.center_y
  
  var keypoints = Dictionary<Int, [Float]>()
  for k in 0..<K {
    let x = output.keypoints[[0, k, 0] as [NSNumber]]
    let y = output.keypoints[[0, k, 1] as [NSNumber]]
    let score = output.scores[[0, k] as [NSNumber]]
    
    let originalX = (x.floatValue * sx) + cx - ((scale_x * 200) / 2)
    let originalY = (y.floatValue * sy) + cy - ((scale_y * 200) / 2)
    keypoints[k] = [originalX / Float(img.width), originalY / Float(img.height), score.floatValue]
  }
  
  let t4 = CFAbsoluteTimeGetCurrent()
  let totalTime = (t4 - t1) * 1000
  print("End-to-end \(totalTime) ms")
  return keypoints
}

@available(iOS 14.0, *)
func runVipnasInference(img: CGImage, bbox: [Int]) -> Dictionary<Int, [Float]> {
  let ptr = pixelsRGB(img: img)
  let originalImage = RgbImage(rgb: ptr, height: Int32(img.height), width: Int32(img.width))
  return runVipnasInference(img: originalImage, bbox: bbox)
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
