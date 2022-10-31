import XCTest
@testable import GuruSwiftSDK
import Mocker

final class AnalysisTests: XCTestCase {
  
  let videoId = TestUtils.randomString()
  let apiKey = TestUtils.randomString()
  
  func testAnalysisFrameCanBePushedToServer() async throws {
    let frameInference = randomFrameInference()
    let analysisClient = AnalysisClient(videoId: videoId, apiKey: apiKey)
    let expectedAnalysis = randomAnalysis()
    Mock(url: URL(string: "https://api.getguru.fitness/videos/\(videoId)/j2p")!,
         dataType: .json,
         statusCode: 200,
         data: [.patch : analysisToResponse(expectedAnalysis)]
    ).register()
    
    let actualAnalysis = try! await analysisClient.add(inference: frameInference)
    
    XCTAssertEqual(expectedAnalysis, actualAnalysis)
  }
  
  func testNSErrorIsTransformed() async throws {
    let frameInference = randomFrameInference()
    let analysisClient = AnalysisClient(videoId: videoId, apiKey: apiKey)
    let expectedAnalysis = randomAnalysis()
    Mock(url: URL(string: "https://api.getguru.fitness/videos/\(videoId)/j2p")!,
         dataType: .json,
         statusCode: 200,
         data: [.patch : analysisToResponse(expectedAnalysis)],
         requestError: NSError(domain: NSURLErrorDomain, code: -1005)
    ).register()
    
    do {
      try await analysisClient.add(inference: frameInference)
    }
    catch is APICallFailed {
      // expected
    }
  }
  
  func analysisToResponse(_ analysis: Analysis) -> Data {
    return try! JSONSerialization.data(
      withJSONObject: [
        "liftType": analysis.movement!,
        "reps": analysis.reps.map {
          [
            "startTimestampMs": $0.startTimestamp,
            "midTimestampMs": $0.midTimestamp,
            "endTimestampMs": $0.endTimestamp,
            "analyses": $0.analyses.map {
              [
                "analysisType": $0,
                "analysisScalar": $1
              ]
            }
          ]
        }
      ],
      options: .prettyPrinted
    )
  }
  
  func randomAnalysis() -> Analysis {
    return Analysis(movement: TestUtils.randomString(), reps: [
      Rep(
        startTimestamp: 0,
        midTimestamp: UInt64(TestUtils.randomInteger(max: 100) + 1),
        endTimestamp: UInt64(TestUtils.randomInteger(max: 100) + 100),
        analyses: [
          TestUtils.randomString(): TestUtils.randomDouble()
        ])
    ])
  }
  
  func randomFrameInference() -> FrameInference {
    return FrameInference(
      keypoints: [cocoLabelToIdx["left_wrist"]!: TestUtils.randomKeypoint()],
      timestamp: Date(),
      secondsSinceStart: 1.0,
      frameIndex: 0,
      previousFrame: nil
    )
  }
  

}
