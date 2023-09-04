import C
import Foundation
import CoreGraphics
import UIKit

public class GuruEngine {
  
  let modelStore = ModelStore()

  public init(apiKey: String, userCode: String) async {
    let auth = APIKeyAuth(apiKey: apiKey)
    let poseModel = try! await self.modelStore.getModel(auth: auth, type: ModelMetadata.ModelType.pose).get()

    userCode.withCString({ userCodePtr in
      poseModel.path.withCString({ filePathPtr in
        if (C.init_engine(UnsafeMutablePointer(mutating: userCodePtr), UnsafeMutablePointer(mutating: filePathPtr)) != 0) {
          fatalError("Failed to initialize the engine");
        }
      })
    })
  }
  
  public func processFrame(image: UIImage) -> Any {
    var rgbImage = self.toRgbImage(image: image)
    defer { rgbImage.data.deallocate() }
    let result = withUnsafeMutablePointer(to: &rgbImage) { imagePtr in
      var state = EngineState(target_fps: 1.0)
      return withUnsafeMutablePointer(to: &state) { enginePtr in
        return C.process_frame(enginePtr, imagePtr)
      }
    }
    
    let jsonResult = try! JSONSerialization.jsonObject(
      with: String(cString: result!).data(using: .utf8)!
    )
    
    return jsonResult
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
