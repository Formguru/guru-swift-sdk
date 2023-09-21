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
  var analyzeJSContext: JSContext!
  var renderJSContext: JSContext!
  
  public init(apiKey: String, schemaId: String) async throws {
    self.apiKey = apiKey
    
    self.schema = try await self.getSchema(schemaId: schemaId)
    self.guruEngine = await GuruEngine(apiKey: apiKey, userCode: self.schema["inferenceCode"] as! String)
    self.analyzeJSContext = self.initAnalyzeJSContext()
    self.renderJSContext = self.initRenderJSContext()
  }
  
  public func finish() {
    // TODO: Shut the engine down gracefully
  }
  
  public func newFrame(frame: UIImage) -> GuruAnalysis? {
    if (!inferenceLock.try()) {
      if (lastAnalysis == nil) {
        return GuruAnalysis(result: nil, processResult: [:])
      }
      else {
        return lastAnalysis!
      }
    }
    defer { self.inferenceLock.unlock() }

    // TODO: how should we handle errors?
    guard let inferenceResult = self.guruEngine.processFrame(image: frame) else {
      return nil
    }
    
    self.previousInferences.append(inferenceResult)
    let analysisResult = self.analyze(previousInferences)
    let analysis = GuruAnalysis(result: analysisResult, processResult: inferenceResult)
    
    self.lastAnalysis = analysis
    return analysis
  }
  
  public func renderFrame(frame: UIImage, analysis: GuruAnalysis) -> UIImage {
    let painter = AnalysisPainter(frame: frame)
    
    let drawBoundingBox: @convention(block) ([String: Any], [String: Int], Double) -> Bool = { object, color, width in
      painter.boundingBox(
        box: object["boundary"] as! [String: [String: Double]],
        color: color,
        width: width.isNaN ? 2.0 : width
      )
      return true
    }
    self.renderJSContext.setObject(drawBoundingBox, forKeyedSubscript: "drawBoundingBox" as NSString)
    let drawSkeleton: @convention(block) ([String: Any], [String: Int], [String: Int], Double, Double) -> Bool = { object, lineColor, keypointColor, lineWidth, keypointRadius in
      guard let keypoints = object["keypoints"] as? [String: [String: Double]] else {
        return false
      }
      painter.skeleton(
        keypoints: object["keypoints"] as! [String: [String: Double]],
        lineColor: lineColor,
        keypointColor: keypointColor,
        lineWidth: lineWidth.isNaN ? 2 : lineWidth,
        keypointRadius: keypointRadius.isNaN ? 5 : keypointRadius
      )
      return true
    }
    self.renderJSContext.setObject(drawSkeleton, forKeyedSubscript: "drawSkeleton" as NSString)

    let render = self.renderJSContext.objectForKeyedSubscript("invoke")
    render!.call(withArguments: [analysis.processResult])
    
    return painter.finish()
  }
  
  private func analyze(_ inferenceResults: [Any]) -> JSValue? {
    var analysisResult: JSValue? = nil
    let analysisFinished: @convention(block) (JSValue?) -> Bool = { result in
      analysisResult = result
      return true
    }
    self.analyzeJSContext.setObject(analysisFinished, forKeyedSubscript: "analysisFinished" as NSString)
    
    let render = self.analyzeJSContext.objectForKeyedSubscript("invoke")
    render!.call(withArguments: [inferenceResults])
    
    return analysisResult
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
  
  private func initAnalyzeJSContext() -> JSContext {
    let context = JSContext()!
    context.exceptionHandler = {context, exception in
      print("Analysis exception: \(String(describing: exception))")
    }

    let log: @convention(block) (String) -> Bool = { message in
      print(message)
      return true
    }
    context.setObject(log, forKeyedSubscript: "log" as NSString)
    
    let code = """
\(self.schema["analyzeVideoCode"] as! String)

function invoke(frameResults) {
  console.log = log;
  analyzeVideo(frameResults).then(analysisFinished);
}
"""
    context.evaluateScript(code)
    
    return context;
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
    
    return context;
  }
}
