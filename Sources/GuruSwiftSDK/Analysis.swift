/* Copyright (C) Guru Movement Labs Inc - All Rights Reserved
 * Unauthorized copying of this file, via any medium, is strictly prohibited.
 * Proprietary and confidential.
 */

import Foundation

public struct Analysis: Equatable {
  public let movement: String?
  public let reps: [Rep]
  
  static public func ==(lhs: Analysis, rhs: Analysis) -> Bool {
    return lhs.movement == rhs.movement && lhs.reps == rhs.reps
  }
}

public struct Rep: Equatable {
  public let startTimestamp: UInt64
  public let midTimestamp: UInt64
  public let endTimestamp: UInt64
  public let analyses: [String: Any]
  
  static public func ==(lhs: Rep, rhs: Rep) -> Bool {
    return lhs.startTimestamp == rhs.startTimestamp &&
        lhs.midTimestamp == rhs.midTimestamp &&
        lhs.endTimestamp == rhs.endTimestamp &&
        NSDictionary(dictionary: lhs.analyses).isEqual(to: rhs.analyses)
  }
}

class AnalysisClient {
  var buffer = [FrameInference]()
  let bufferLock = NSLock()
  let buildLock = NSLock()
  let videoId: String
  let apiKey: String
  let maxBufferSize = 1000
  
  let maxPerSecond: Double
  var numTokens: Double
  var tokensLastReplenished: Date
  
  init(videoId: String, apiKey: String, maxPerSecond: Int = 8) {
    self.videoId = videoId
    self.apiKey = apiKey
    self.maxPerSecond = Double(maxPerSecond)
    
    self.numTokens = self.maxPerSecond
    self.tokensLastReplenished = Date()
  }
  
  func add(inference: FrameInference) async throws -> Analysis? {
    if (bufferLock.lock(before: Date().addingTimeInterval(TimeInterval(10)))) {
      if (readyToBuffer()) {
        buffer.append(inference)
        
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
    if (bufferLock.lock(before: Date().addingTimeInterval(TimeInterval(30)))) {
      bufferLock.unlock()
    }
    
    if (buildLock.lock(before: Date().addingTimeInterval(TimeInterval(30)))) {
      buildLock.unlock()
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
      let keypoint = inference.keypointForLandmark(nextLandmark)
      
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
    if (json["reps"] != nil) {
      for rep: [String: Any] in (json["reps"] as! [[String: Any]]) {
        reps.append(Rep(
          startTimestamp: rep["startTimestampMs"] as! UInt64,
          midTimestamp: rep["midTimestampMs"] as! UInt64,
          endTimestamp: rep["endTimestampMs"] as! UInt64,
          analyses: Dictionary(uniqueKeysWithValues: (rep["analyses"] as! [[String: Any]]).map{ ($0["analysisType"] as! String, $0["analysisScalar"]) })
        ))
      }
    }
    
    return Analysis(movement: json["liftType"] as? String, reps: reps)
  }
  
  private func readyToBuffer() -> Bool {
    replenishTokens();
    
    if (numTokens >= 1.0) {
      numTokens -= 1.0
      return true
    }
    else {
      return false
    }
  }
  
  private func replenishTokens() {
    let now = Date()
    if (numTokens < maxPerSecond) {
      numTokens += (now.timeIntervalSince1970 - tokensLastReplenished.timeIntervalSince1970) * maxPerSecond

      if (numTokens > maxPerSecond) {
        numTokens = maxPerSecond
      }
    }
    tokensLastReplenished = now
  }
}
