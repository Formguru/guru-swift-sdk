import C
import Foundation
import CoreGraphics
import UIKit

public class GuruEngine {
  
  let onnxUrl = Bundle.module.path(forResource: "vipnas", ofType: "onnx")

  public init(userCode: String) {    
    if !(FileManager().fileExists(atPath: onnxUrl!)) {
      fatalError("ONNX model does not exist")
    }

    userCode.withCString({ userCodePtr in
      onnxUrl!.withCString({ filePathPtr in
        if (C.init_engine(UnsafeMutablePointer(mutating: userCodePtr), UnsafeMutablePointer(mutating: filePathPtr)) != 0) {
          fatalError("Failed to initialize the engine");
        }
      })
    })
  }
  
  public func processFrame(image: UIImage) {
    var rgbImage = self.toRgbImage(image: image)
    defer { rgbImage.data.deallocate() }
    let result = withUnsafeMutablePointer(to: &rgbImage) { imagePtr in
      var state = EngineState(target_fps: 1.0)
      return withUnsafeMutablePointer(to: &state) { enginePtr in
        return C.process_frame(enginePtr, imagePtr)
      }
    }
    
    if (result != 0) {
      // FIXME: how should we handle this?
      fatalError("Fatal error in processing frame");
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
  
  private func toRgbImage(image: UIImage) -> RgbImage {
    let cgImage = image.cgImage
    let pixelsPtr = pixelsRGB(img: cgImage!)
    return RgbImage(data: pixelsPtr, width: Int32(cgImage!.width), height: Int32(cgImage!.height))
  }
}
