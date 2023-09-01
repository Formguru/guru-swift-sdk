import Foundation
import UIKit
import JavaScriptCore

public class GuruVideo {
  let apiKey: String
  var schema: [String: Any]!
  var guruEngine: GuruEngine!
  let inferenceLock = NSLock()
  var latestInference: GuruAnalysis = GuruAnalysis(result: [:])
  
  public init(apiKey: String, schemaId: String) async throws {
    self.apiKey = apiKey
    
    self.schema = try await self.getSchema(schemaId: schemaId)
    self.guruEngine = GuruEngine(userCode: self.schema["inferenceCode"] as! String)
  }
  
  public func finish() {
    // TODO: Shut the engine down gracefully
  }
  
  public func newFrame(frame: UIImage) -> GuruAnalysis {
    if (!inferenceLock.try()) {
      return latestInference
    }
    defer { self.inferenceLock.unlock() }

    let engineResult = self.guruEngine.processFrame(image: frame)
    return GuruAnalysis(result: engineResult)
  }
  
  public func renderFrame(frame: UIImage, analysis: GuruAnalysis) -> UIImage {
    let context = JSContext()!
    context.exceptionHandler = {context, exception in
      print("Exception: \(String(describing: exception))")
    }
    
    let painter = AnalysisPainter(frame: frame)
    
    let drawBoundingBox: @convention(block) ([String: Any], [String: Int], Double) -> Bool = { object, color, width in
      painter.boundingBox(
        box: object["boundary"] as! [String: [String: Double]],
        color: color,
        width: width.isNaN ? 2.0 : width
      )
      return true
    }
    context.setObject(drawBoundingBox, forKeyedSubscript: "drawBoundingBox" as NSString)
    let drawSkeleton: @convention(block) ([String: Any], [String: Int], [String: Int], Double, Double) -> Bool = { object, lineColor, keypointColor, lineWidth, keypointRadius in
      painter.skeleton(
        keypoints: object["keypoints"] as! [String: [String: Double]],
        lineColor: lineColor,
        keypointColor: keypointColor,
        lineWidth: lineWidth.isNaN ? 2 : lineWidth,
        keypointRadius: keypointRadius.isNaN ? 5 : keypointRadius
      )
      return true
    }
    context.setObject(drawSkeleton, forKeyedSubscript: "drawSkeleton" as NSString)
    let log: @convention(block) (String) -> Bool = { message in
      print(message)
      return true
    }
    context.setObject(log, forKeyedSubscript: "log" as NSString)
    
    let code = """
class FrameCanvas {
  constructor() {
    this.drawBoundingBox = drawBoundingBox;
    this.drawSkeleton = drawSkeleton;
  }
}

class Color {
  constructor(r, g, b) {
    this.r = r;
    this.g = g;
    this.b = b;
  }
}

\(self.schema["renderCode"] as! String)

function invoke(processResult) {
  console.log = log;
  renderFrame(new FrameCanvas(), processResult);
}
"""
    context.evaluateScript(code)
    let render = context.objectForKeyedSubscript("invoke")
    render!.call(withArguments: [analysis.result])
    
    return painter.finish()
  }
  
  private func getSchema(schemaId: String) async throws -> [String: Any] {
    var request = URLRequest(url: URL(string: "https://api.getguru.fitness/schemas/\(schemaId)")!)
    request.setValue(self.apiKey, forHTTPHeaderField: "x-api-key")

    do {
      let (data, response) = try await URLSession.shared.data(for: request)

      if ((response as? HTTPURLResponse)!.statusCode == 200) {
        return try! JSONSerialization.jsonObject(with: data) as! [String: Any]
      }
      else {
        throw APICallFailed.getSchemaFailed(error: String(decoding: data, as: UTF8.self))
      }
    }
    catch let error as NSError {
      throw APICallFailed.getSchemaFailed(error: error.localizedDescription)
    }
  }
}
