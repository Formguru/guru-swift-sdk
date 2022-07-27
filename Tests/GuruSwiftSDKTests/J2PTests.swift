import XCTest
@testable import GuruSwiftSDK

final class J2PTests: XCTestCase {
  
  func testKeypointForLandmarkReturnsKeypoint() {
    let keypoint = Keypoint(x: 0.5, y: 0.5, score: 1.0)
    
    let frameInference = defaultFrameInference(keypoints: [
      cocoLabelToIdx["left_wrist"]!: keypoint
    ])
    
    XCTAssertEqual(frameInference.keypointForLandmark(InferenceLandmark.leftWrist), keypoint)
  }
  
  func testUserFacingLeft() {
    let frameInference = defaultFrameInference(keypoints: [
      cocoLabelToIdx["nose"]!: Keypoint(x: 0.5, y: 0.3, score: 1.0),
      cocoLabelToIdx["left_shoulder"]!: Keypoint(x: 0.4, y: 0.4, score: 1.0),
      cocoLabelToIdx["right_shoulder"]!: Keypoint(x: 0.4, y: 0.4, score: 1.0)
    ])
    
    XCTAssertEqual(frameInference.userFacing(), UserFacing.left)
  }
  
  func testUserFacingRight() {
    let frameInference = defaultFrameInference(keypoints: [
      cocoLabelToIdx["nose"]!: Keypoint(x: 0.4, y: 0.3, score: 1.0),
      cocoLabelToIdx["left_shoulder"]!: Keypoint(x: 0.5, y: 0.4, score: 1.0),
      cocoLabelToIdx["right_shoulder"]!: Keypoint(x: 0.5, y: 0.4, score: 1.0)
    ])
    
    XCTAssertEqual(frameInference.userFacing(), UserFacing.right)
  }
  
  func testUserFacingOtherIfNoNose() {
    let frameInference = defaultFrameInference(keypoints: [
      cocoLabelToIdx["left_shoulder"]!: Keypoint(x: 0.5, y: 0.4, score: 1.0),
      cocoLabelToIdx["right_shoulder"]!: Keypoint(x: 0.5, y: 0.4, score: 1.0)
    ])
    
    XCTAssertEqual(frameInference.userFacing(), UserFacing.other)
  }
  
  func testUserFacingOtherIfMissingShoulder() {
    let frameInference = defaultFrameInference(keypoints: [
      cocoLabelToIdx["nose"]!: Keypoint(x: 0.5, y: 0.3, score: 1.0),
      cocoLabelToIdx["right_shoulder"]!: Keypoint(x: 0.4, y: 0.4, score: 1.0)
    ])
    
    XCTAssertEqual(frameInference.userFacing(), UserFacing.other)
  }
  
  func defaultFrameInference(keypoints: [Int: Keypoint] = [:]) -> FrameInference {
    return FrameInference(
      keypoints: keypoints,
      timestamp: Date(),
      secondsSinceStart: 1.0,
      frameIndex: 0
    )
  }
}
