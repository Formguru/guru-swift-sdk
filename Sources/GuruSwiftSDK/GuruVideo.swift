import Foundation
import UIKit
import JavaScriptCore

public class GuruVideo {
  let apiKey: String
  var schema: [String: Any]!
  var guruEngine: GuruEngine!
  let inferenceLock = NSLock()
  var previousInferences: [Any] = []
  var lastAnalysis: GuruAnalysis?
  var renderJSContext: JSContext!
  let startTime = Date()
  
  public init(apiKey: String, schemaId: String) async throws {
    self.apiKey = apiKey
    
    self.schema = try await self.getSchema(schemaId: schemaId)
    self.guruEngine = await GuruEngine(
      apiKey: apiKey,
      userCode: self.schema["inferenceCode"] as! String,
      analyzeCode: self.schema["analyzeVideoCode"] as! String
    )
    self.renderJSContext = self.initRenderJSContext()
  }
  
  public func finish() {
    // TODO: Shut the engine down gracefully
  }
  
  public func newFrame(frame: UIImage) -> GuruAnalysis? {
    if (!inferenceLock.try()) {
      if (lastAnalysis == nil) {
        return GuruAnalysis(result: nil, processResult: [:], frameTimestamp: 0)
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
    
    self.previousInferences.append(inferenceResult)
    let analysisResult = self.analyze(previousInferences)
    let analysis = GuruAnalysis(result: analysisResult, processResult: inferenceResult, frameTimestamp: frameTimestamp)
    
    self.lastAnalysis = analysis
    return analysis
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
    self.renderJSContext.setObject(drawBoundingBox, forKeyedSubscript: "drawBoundingBox" as NSString)
    
    let drawCircle: @convention(block) ([String: Double], Int, [String: Int], [String: Any]?) -> Bool = { position, radius, color, params in
      painter.circle(center: position, radius: radius, color: color, params: params)
      return true
    }
    self.renderJSContext.setObject(drawCircle, forKeyedSubscript: "drawCircle" as NSString)
    
    let drawLine: @convention(block) ([String: Double], [String: Double], [String: Int], [String: Any]?) -> Bool = { from, to, color, params in
      painter.line(from: from, to: to, color: color, params: params)
      return true
    }
    self.renderJSContext.setObject(drawLine, forKeyedSubscript: "drawLine" as NSString)
    
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
    self.renderJSContext.setObject(drawRect, forKeyedSubscript: "drawRect" as NSString)
    
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
    self.renderJSContext.setObject(drawSkeleton, forKeyedSubscript: "drawSkeleton" as NSString)
    
    let drawText: @convention(block) (String, [String: Double], [String: Int], [String: Any]?) -> Bool = { text, position, color, params in
      painter.text(text: text, position: position, color: color, params: params)
      return true
    }
    self.renderJSContext.setObject(drawText, forKeyedSubscript: "drawText" as NSString)

    let render = self.renderJSContext.objectForKeyedSubscript("invoke")
    render!.call(withArguments: [
      analysis.frameTimestamp,
      analysis.processResult,
      [
        "analyzeResult": analysis.result
      ]
    ])
    
    return painter.finish()
  }
  
  private func analyze(_ inferenceResults: [Any]) -> Any? {
    return guruEngine.analyzeVideo(frameResults: inferenceResults)
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
  
  private func initRenderJSContext() -> JSContext {
    let context = JSContext()!
    context.exceptionHandler = {context, exception in
      print("Rendering exception: \(String(describing: exception))")
    }

    let log: @convention(block) (String) -> Bool = { message in
      print(message)
      return true
    }
    context.setObject(log, forKeyedSubscript: "log" as NSString)
    
    let code = """
class FrameCanvas {
  constructor(timestamp) {
    this.timestamp = timestamp;
    this.drawBoundingBox = drawBoundingBox;
    this.drawCircle = drawCircle;
    this.drawLine = drawLine;
    this.drawRect = drawRect;
    this.drawSkeleton = drawSkeleton;
    this.drawText = drawText;
  }
}

class Color {
  constructor(r, g, b) {
    this.r = r;
    this.g = g;
    this.b = b;
  }
}

class Position {
  constructor(x, y, confidence) {
    this.x = x;
    this.y = y;
    this.confidence = confidence;
  }
}

\(self.schema["renderCode"] as! String)

function invoke(timestamp, processResult, args) {
  console.log = log;
  renderFrame(new FrameCanvas(timestamp), processResult, args);
}
"""
    context.evaluateScript(code)
    
    return context;
  }
}
