import C
import Foundation
import CoreGraphics
import UIKit
import os
import Foundation

public class GuruEngine {
  
  let modelStore = ModelStore()
  var lastInferenceTime: Date? = nil
  
  func withManifest(bundle: Bundle, jsLibPaths: [String], onnxModels: [String : String], userCode: String, closure: (Manifest) -> Void) {
    
    var ptrs: [UnsafeRawPointer] = []
    func allocate(_ s: String) -> UnsafePointer<CChar>? {
      let p = strdup(s)
      ptrs.append(p!)
      return UnsafePointer(p)
    }
    
    let js_lib_root = allocate(bundle.bundlePath)
    var jsFileCPaths = jsLibPaths.map { allocate($0) }
    jsLibPaths.forEach { p in
      let fullPath = bundle.bundlePath + "/" + p
      if !FileManager.default.fileExists(atPath: fullPath) {
        fatalError("jsLib \(fullPath) does not exist")
      }
    }
    
    var onnxModelStructs = onnxModels.map { (k, v) in
      let name = allocate(k)
      // TODO: verify a file at this path exists
      let path = allocate(v)
      return OnnxModel(name: name, file_path: path)
    }
    let userCodeStr = allocate(userCode)
    
    jsFileCPaths.withUnsafeMutableBufferPointer( { ptr in
      let js_lib_paths = ptr.baseAddress
      onnxModelStructs.withUnsafeMutableBufferPointer( { ptr in
        let onnx_models = ptr.baseAddress
        var manifest = Manifest(
          js_lib_root: js_lib_root,
          js_lib_paths: js_lib_paths,
          num_js_lib_paths: Int32(jsLibPaths.count),
          user_code: userCodeStr,
          onnx_models: onnx_models,
          num_onnx_models: Int32(onnxModels.keys.count)
        )
        closure(manifest)
      })
    })
    for ptr in ptrs {
      var _ptr = ptr
      free(UnsafeMutableRawPointer(mutating: _ptr))
    }
  }
  
  public init(apiKey: String, userCode: String) async {
    let auth = APIKeyAuth(apiKey: apiKey)
    let poseModel = try! await self.modelStore.getModel(auth: auth, type: ModelMetadata.ModelType.pose).get()
    let personDetModel = try! await self.modelStore.getModel(auth: auth, type: ModelMetadata.ModelType.person).get()
    let onnxModels = [
      "guru-rtmpose-img-256x192": poseModel.path,
      "tiny-yolov3": personDetModel.path
    ]
    guard let bundleURL = Bundle.module.url(forResource: "javascript", withExtension: "bundle"),
          let bundle = Bundle(url: bundleURL)
    else {
      fatalError("Could not find bundle")
    }
    let jsFiles = ["javascript/inference_utils.mjs", "javascript/guru_stdlib.mjs"]
    withManifest(
      bundle: bundle,
      jsLibPaths: jsFiles,
      onnxModels: onnxModels,
      userCode: userCode
    ) { manifest in
      var _manifest = manifest
      withUnsafeMutablePointer(to: &_manifest, { manifestPtr in
        let result = C.init_engine(manifestPtr)
        if (result != 0) {
          fatalError("Failed to initialize the engine");
        }
      })
    }
  }
  
  func measureInMilliseconds(_ block: () -> ()) -> UInt64 {
    let start = DispatchTime.now()
    block()
    let end = DispatchTime.now()
    let nanos = end.uptimeNanoseconds - start.uptimeNanoseconds
    let ms = nanos / 1_000_000
    return ms
  }

  public func processFrame(image: UIImage) -> Any? {
    var result: UnsafePointer<CChar>? = nil
    self.withRgbImage(image: image, { imagePtr in
      var state = EngineState(target_fps: 1.0)
      withUnsafeMutablePointer(to: &state) { enginePtr in
        let msElapsed = measureInMilliseconds {
          result = C.process_frame(enginePtr, imagePtr)
        }
        // print("process_frame() took \(msElapsed) ms (\(1000.0 / Double(msElapsed)) fps)")
      }
    })
    let now = Date()
    if lastInferenceTime != nil {
      let elapsed = now.timeIntervalSince(lastInferenceTime!)
      // print("Inference took \(elapsed * 1000) ms (\(1.0 / elapsed) fps)")
    }
    lastInferenceTime = now
    if result != nil, let jsonResult = parseJSON(result!) {
      return jsonResult
    } else {
      print("processFrame() did not return a valid result!")
      return nil
    }
  }
  
  private enum Container {
    case dict([String : Any])
    case array([Any])
  }
  
  private func parseJSON(_ result: UnsafePointer<CChar>) -> [String: Any]? {
    let stringResult = String(cString: result)
    if let stringData = stringResult.data(using: .utf8),
       let rawJsonResult = try? JSONSerialization.jsonObject(with: stringData) as? [String: Any] {
      return parseStringsAsNumbers(.dict(rawJsonResult)) as? [String : Any]
    }
    return nil
  }
  
  private func parseStringsAsNumbers(_ container: Container) -> Any {
    switch container {
    case .dict(let dict):
      var newDict = [String : Any]()
      for (key, value) in dict {
        if let strValue = value as? String, let floatValue = Float(strValue) {
          newDict[key] = floatValue
        } else if let innerDict = value as? [String: Any] {
          newDict[key] = parseStringsAsNumbers(.dict(innerDict))
        } else if let innerArray = value as? [Any] {
          newDict[key] = parseStringsAsNumbers(.array(innerArray))
        } else {
          newDict[key] = value
        }
      }
      return newDict
    case .array(let array):
      var newArray = [Any]()
      for element in array {
        if let strValue = element as? String, let floatValue = Float(strValue) {
          newArray.append(floatValue)
        } else if let innerDict = element as? [String : Any] {
          newArray.append(parseStringsAsNumbers(.dict(innerDict)))
        } else if let innerArray = element as? [Any] {
          newArray.append(parseStringsAsNumbers(.array(innerArray)))
        } else {
          newArray.append(element)
        }
      }
      return newArray
    }
  }
  
  private func pixelsRGB(img: CGImage) -> UnsafeMutablePointer<UInt8> {
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
  
  private func withRgbImage(image: UIImage, _ closure: (UnsafeMutablePointer<RgbImage>) -> Void) {
    let cgImage = image.cgImage
    let pixelsPtr = pixelsRGB(img: cgImage!)
    defer {
      pixelsPtr.deallocate()
    }
    var rgbImg = RgbImage(data: pixelsPtr, width: Int32(cgImage!.width), height: Int32(cgImage!.height), channel_order: BGRA)
    withUnsafeMutablePointer(to: &rgbImg, { ptr in
      closure(ptr)
    })
  }
}
