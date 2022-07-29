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
  
  func testKeypointsAreSmoothed() {
    let previousKeypoint = Keypoint(x: 0.4, y: 0.4, score: 1.0)
    let keypoint = Keypoint(x: 0.5, y: 0.5, score: 1.0)
    
    let frameInference = defaultFrameInference(keypoints: [
      cocoLabelToIdx["left_wrist"]!: keypoint
    ], previousFrame: defaultFrameInference(keypoints: [
      cocoLabelToIdx["left_wrist"]!: previousKeypoint
    ]))
    
    XCTAssertEqual(
      String(format: "%.3f", frameInference.keypointForLandmark(InferenceLandmark.leftWrist)!.x),
      String(format: "%.3f", 0.425)
    )
    XCTAssertEqual(
      String(format: "%.3f", frameInference.keypointForLandmark(InferenceLandmark.leftWrist)!.y),
      String(format: "%.3f", 0.425)
    )
  }
  
  func testUserFacingLeft() {
    let frameInference = defaultFrameInference(keypoints: [
      cocoLabelToIdx["nose"]!: Keypoint(x: 0.5, y: 0.3, score: 1.0),
      cocoLabelToIdx["left_ear"]!: Keypoint(x: 0.4, y: 0.4, score: 1.0),
      cocoLabelToIdx["right_ear"]!: Keypoint(x: 0.4, y: 0.4, score: 1.0)
    ])
    
    XCTAssertEqual(frameInference.userFacing(), UserFacing.left)
  }
  
  func testUserFacingRight() {
    let frameInference = defaultFrameInference(keypoints: [
      cocoLabelToIdx["nose"]!: Keypoint(x: 0.4, y: 0.3, score: 1.0),
      cocoLabelToIdx["left_ear"]!: Keypoint(x: 0.5, y: 0.4, score: 1.0),
      cocoLabelToIdx["right_ear"]!: Keypoint(x: 0.5, y: 0.4, score: 1.0)
    ])
    
    XCTAssertEqual(frameInference.userFacing(), UserFacing.right)
  }
  
  func testUserFacingOtherIfNoNose() {
    let frameInference = defaultFrameInference(keypoints: [
      cocoLabelToIdx["left_ear"]!: Keypoint(x: 0.5, y: 0.4, score: 1.0),
      cocoLabelToIdx["right_ear"]!: Keypoint(x: 0.5, y: 0.4, score: 1.0)
    ])
    
    XCTAssertEqual(frameInference.userFacing(), UserFacing.other)
  }
  
  func testUserFacingOtherIfMissingEar() {
    let frameInference = defaultFrameInference(keypoints: [
      cocoLabelToIdx["nose"]!: Keypoint(x: 0.5, y: 0.3, score: 1.0),
      cocoLabelToIdx["right_ear"]!: Keypoint(x: 0.4, y: 0.4, score: 1.0)
    ])
    
    XCTAssertEqual(frameInference.userFacing(), UserFacing.other)
  }
  
  func defaultFrameInference(keypoints: [Int: Keypoint] = [:], previousFrame: FrameInference? = nil) -> FrameInference {
    return FrameInference(
      keypoints: keypoints,
      timestamp: Date(),
      secondsSinceStart: 1.0,
      frameIndex: 0,
      previousFrame: previousFrame
    )
  }
}
