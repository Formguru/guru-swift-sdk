/* Copyright (C) Guru Movement Labs Inc - All Rights Reserved
 * Unauthorized copying of this file, via any medium, is strictly prohibited.
 * Proprietary and confidential.
 */

import Foundation

public struct Analysis {
  public let movement: String?
  public let reps: [Rep]
}

public struct Rep {
  public let startTimestamp: UInt64
  public let midTimestamp: UInt64
  public let endTimestamp: UInt64
  public let analyses: [String: Any]
}

class AnalysisClient {
  var buffer = [FrameInference]()
  var lastBufferedTimestamp: Date?
  let bufferLock = NSLock()
  let buildLock = NSLock()
  let videoId: String
  let apiKey: String
  let maxBufferSize = 100
  let inferencePerSecond = 8.0
  
  init(videoId: String, apiKey: String) {
    self.videoId = videoId
    self.apiKey = apiKey
  }
  
  func add(inference: FrameInference) async throws -> Analysis? {
    if (bufferLock.lock(before: Date().addingTimeInterval(TimeInterval(10)))) {
      if (readyToBuffer()) {
        buffer.append(inference)
        lastBufferedTimestamp = Date()
        
        while (buffer.count > maxBufferSize) {
          buffer.removeFirst()
        }
      }

      bufferLock.unlock()
    }
    
    if (!buffer.isEmpty) {
      return try await flush()
    }
    else {
      return nil
    }
  }
  
  func flush() async throws -> Analysis? {
    if (buildLock.try()) {
      defer { buildLock.unlock() }
      
      let bufferCopy = buffer
      let analysis = try await patchAnalysis(frames: bufferCopy)
      
      if (bufferLock.lock(before: Date().addingTimeInterval(TimeInterval(10)))) {
        buffer = Array(buffer.dropFirst(bufferCopy.count))
        bufferLock.unlock()
      }
      
      return analysis
    }
    else {
      return nil
    }
  }
  
  func waitUntilQuiet() {
    if (bufferLock.lock(before: Date().addingTimeInterval(TimeInterval(10)))) {
      bufferLock.unlock()
      if (buildLock.lock(before: Date().addingTimeInterval(TimeInterval(10)))) {
        buildLock.unlock()
        return
      }
    }
  }
  
  private func patchAnalysis(frames: [FrameInference]) async throws -> Analysis {
    var request = URLRequest(url: URL(string: "https://api.getguru.fitness/videos/\(videoId)/j2p")!)
    request.httpMethod = "PATCH"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
    request.httpBody = try! JSONSerialization.data(withJSONObject: frames.map(frameInferenceToJson))
    
    let (data, response) = try! await URLSession.shared.data(for: request)
    
    if ((response as? HTTPURLResponse)!.statusCode == 200) {
      let json = try! JSONSerialization.jsonObject(with: data) as! [String: AnyObject]
      return jsonToAnalysis(json: json)
    }
    else {
      throw APICallFailed.updateAnalysisFailed(error: String(decoding: data, as: UTF8.self))
    }
  }
  
  private func frameInferenceToJson(_ inference: FrameInference) -> [String: Any] {
    var json = [String: Any]()
    json["frameIndex"] = inference.frameIndex
    json["timestamp"] = inference.secondsSinceStart
    
    for nextLandmark in InferenceLandmark.allCases {
      let keypoint = inference.keypointForLandmark(landmark: nextLandmark)
      
      if (keypoint != nil) {
        json["\(nextLandmark)"] = [
          "x": keypoint!.x,
          "y": keypoint!.y,
          "score": keypoint!.score
        ]
      }
    }
    
    return json
  }
  
  private func jsonToAnalysis(json: [String: Any]) -> Analysis {
    var reps = [Rep]()
    for rep: [String: Any] in (json["reps"] as! [[String: Any]]) {
      reps.append(Rep(
        startTimestamp: rep["startTimestampMs"] as! UInt64,
        midTimestamp: rep["midTimestampMs"] as! UInt64,
        endTimestamp: rep["endTimestampMs"] as! UInt64,
        analyses: Dictionary(uniqueKeysWithValues: (rep["analyses"] as! [[String: Any]]).map{ ($0["analysisType"] as! String, $0["analysisScalar"]) })
      ))
    }
    
    return Analysis(movement: json["liftType"] as? String, reps: reps)
  }
  
  private func readyToBuffer() -> Bool {
    return lastBufferedTimestamp == nil ||
      (Date().timeIntervalSince1970 - lastBufferedTimestamp!.timeIntervalSince1970) > (1.0 / inferencePerSecond)
  }
}
