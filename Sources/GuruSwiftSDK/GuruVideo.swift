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
    let frameTimestamp = Int(Date().timeIntervalSince(self.startTime) * 1000)
    guard let inferenceResult = self.guruEngine.processFrame(image: frame, timestamp: frameTimestamp) else {
      return nil
    }

    self.lastAnalysis = GuruAnalysis(result: inferenceResult, frameTimestamp: frameTimestamp)

    // Return a copy so that the value isn't modified underneath the caller
    return GuruAnalysis(result: self.lastAnalysis!.result, frameTimestamp: self.lastAnalysis!.frameTimestamp)
  }
  
  public func renderFrame(frame: UIImage, analysis: GuruAnalysis) -> UIImage {
    let painter = AnalysisPainter(frame: frame)
    
    let drawBoundingBox: @convention(block) ([String: Any], [String: Int], Double) -> Bool = { object, color, width in
      painter.boundingBox(
        box: object["boundary"] as! [String: [String: Double]],
        borderColor: color,
        backgroundColor: nil,
        width: width.isNaN ? 2.0 : width,
        alpha: 1.0
      )
      return true
    }
    
    let drawCircle: @convention(block) ([String: Double], Int, [String: Int], [String: Any]?) -> Bool = { position, radius, color, params in
      painter.circle(center: position, radius: radius, color: color, params: params)
      return true
    }
    
    let drawLine: @convention(block) ([String: Double], [String: Double], [String: Int], [String: Any]?) -> Bool = { from, to, color, params in
      painter.line(from: from, to: to, color: color, params: params)
      return true
    }
    
    let drawRect: @convention(block) ([String: Double], [String: Double], [String: Any]?) -> Bool = { topLeft, bottomRight, params in
      painter.boundingBox(
        box: [
          "topLeft": topLeft,
          "bottomRight": bottomRight
        ],
        borderColor: params?["borderColor"] as? [String: Int],
        backgroundColor: params?["backgroundColor"] as? [String: Int],
        width: params?["width"] as? Double ?? 2.0,
        alpha: params?["alpha"] as? Double ?? 1.0
      )
      return true
    }
    
    let drawSkeleton: @convention(block) ([String: Any], [String: Int], [String: Int], Double, Double) -> Bool = { object, lineColor, keypointColor, lineWidth, keypointRadius in
      guard let keypoints = object["keypoints"] as? [String: [String: Double]] else {
        return false
      }
      painter.skeleton(
        keypoints: keypoints,
        lineColor: lineColor,
        keypointColor: keypointColor,
        lineWidth: lineWidth.isNaN ? 2 : lineWidth,
        keypointRadius: keypointRadius.isNaN ? 5 : keypointRadius
      )
      return true
    }
    
    let drawText: @convention(block) (String, [String: Double], [String: Int], [String: Any]?) -> Bool = { text, position, color, params in
      painter.text(text: text, position: position, color: color, params: params)
      return true
    }
    
    let drawTriangle: @convention(block) ([String: Double], [String: Double], [String: Double], [String: Any]?) -> Bool = { a, b, c, params in
      painter.triangle(a: a, b: b, c: c, params: params)
      return true
    }
    
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
