import Foundation
import UIKit
import JavaScriptCore

public class GuruVideo {
  let apiKey: String
  var schema: [String: Any]!
  var guruEngine: GuruEngine!
  let inferenceLock = NSLock()
  var lastAnalysis: GuruAnalysis?
  let startTime = Date()
  var renderOperations: [[String: Any]] = []
  
  public init(apiKey: String, schemaId: String) async throws {
    self.apiKey = apiKey
    
    self.schema = try await self.getSchema(schemaId: schemaId)
    self.guruEngine = await GuruEngine(
      apiKey: apiKey,
      userCode: self.schema["code"] as! String
    )
  }
  
  public func finish() {
    // TODO: Shut the engine down gracefully
  }
  
  public func newFrame(frame: UIImage) -> GuruAnalysis? {
    if (!inferenceLock.try()) {
      if (lastAnalysis == nil) {
        return GuruAnalysis(result: nil, frameTimestamp: 0)
      }
      else {
        return lastAnalysis!
      }
    }
    defer { self.inferenceLock.unlock() }

    // TODO: how should we handle errors?
    let frameTimestamp = now()
    guard let processResult = self.guruEngine.processFrame(image: frame, timestamp: frameTimestamp) else {
      return nil
    }

    self.renderOperations = processResult["renderOps"] as! [[String: Any]]
    let inferenceResult = processResult["result"]
    self.lastAnalysis = GuruAnalysis(result: inferenceResult, frameTimestamp: frameTimestamp)

    // Return a copy so that the value isn't modified underneath the caller
    return GuruAnalysis(result: self.lastAnalysis!.result, frameTimestamp: self.lastAnalysis!.frameTimestamp)
  }
  
  public func renderFrame(frame: UIImage, analysis: GuruAnalysis) -> UIImage {
    let painter = AnalysisPainter(frame: frame)
    
    for renderOp in self.renderOperations {
      let name = renderOp["name"] as! String
      let args = renderOp["args"] as! [Any]

      switch name {
      case "drawBoundingBox":
        var frameObjects = args[0] as? [[String: Any]]
        if (frameObjects == nil) {
          frameObjects = [args[0] as! [String: Any]]
        }
        painter.boundingBox(
          box: frameObjects!.last!["boundary"] as! [String: [String: Double]],
          borderColor: args[1] as? [String: Int],
          backgroundColor: nil,
          width: args.count >= 3 ? args[2] as! Double : 2.0,
          alpha: 1.0
        )
      case "drawCircle":
        painter.circle(
          center: args[0] as! [String: Double],
          radius: args[1] as! Int,
          color: args[2] as! [String: Int],
          params: args.count >= 4 ? args[3] as! [String: Any]? : [:]
        )
      case "drawLine":
        painter.line(
          from: args[0] as! [String: Double],
          to: args[1] as! [String: Double],
          color: args[2] as! [String: Int],
          params: args.count >= 4 ? args[3] as! [String: Any] : [:]
        )
      case "drawRect":
        let params = args.count >= 3 ? args[2] as! [String: Any] : [:]
        painter.boundingBox(
          box: [
            "topLeft": args[0] as! [String: Double],
            "bottomRight": args[1] as! [String: Double]
          ],
          borderColor: params["borderColor"] as? [String: Int],
          backgroundColor: params["backgroundColor"] as? [String: Int],
          width: params["width"] as? Double ?? 2.0,
          alpha: params["alpha"] as? Double ?? 1.0
        )
      case "drawSkeleton":
        let frameObjects = args[0] as! [[String: Any]]
        let keypoints = frameObjects.last!["keypoints"] as! [String: [String: Double]]
        painter.skeleton(
          keypoints: keypoints,
          lineColor: args[1] as! [String: Int],
          keypointColor: args[2] as! [String: Int],
          lineWidth: args.count >= 4 ? args[3] as! Double : 2.0,
          keypointRadius: args.count >= 5 ? args[4] as! Double : 5.0
        )
      case "drawText":
        painter.text(
          text: args[0] as! String,
          position: args[1] as! [String: Double],
          color: args[2] as! [String: Int],
          params: args.count >= 4 ? args[3] as! [String: Any] : [:]
        )
      case "drawTriangle":
        painter.triangle(
          a: args[0] as! [String: Double],
          b: args[1] as! [String: Double],
          c: args[2] as! [String: Double],
          params: args.count >= 4 ? args[3] as! [String: Any] : [:]
        )
      default:
        print("Unknown renderOp: \(name)")
      }
    }
    
    return painter.finish()
  }
  
  private func now() -> Int {
    return Int(Date().timeIntervalSince(self.startTime) * 1000);
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
