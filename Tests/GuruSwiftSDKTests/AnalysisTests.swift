import XCTest
@testable import GuruSwiftSDK

final class AnalysisTests: XCTestCase {
  
  let videoId = TestUtils.randomString()
  let apiKey = TestUtils.randomString()
  
  func testKeypointForLandmarkReturnsKeypoint() async throws {
//    let frameInference = randomFrameInference()
//    let analysisClient = AnalysisClient(videoId: videoId, apiKey: apiKey)
//    
//    let analysis = try! await analysisClient.add(inference: frameInference)
//    
//    XCTAssertEqual(Analysis(), analysis)
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
