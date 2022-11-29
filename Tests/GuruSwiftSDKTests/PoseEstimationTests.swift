//
//  PoseEstimationTests.swift
//  GuruTests
//
//  Created by Andrew Stahlman on 6/17/22.
//

import XCTest
import CoreML
@testable import GuruSwiftSDK
import Mocker


@available(iOS 14.0, *)
class PoseEstimationTests: XCTestCase {
  
  override func setUp() async throws {
    let url = URL(string: "https://formguru-datasets.s3.us-west-2.amazonaws.com/on-device/andrew-temp-test/VipnasNoPreprocess.mlpackage.zip")!
    Mock(url: url,
         dataType: .zip,
         statusCode: 200,
         data: [.get : getMLPackageBytes()]
    ).register()
  }
  
  func testPoseModelReturnsSaneResults() async throws {
    let modelStore = ModelStore()
    let jpgUrl = Bundle.module.url(forResource: "steph", withExtension: "jpg")!
    let jpgFile = Bundle.module.path(forResource: "steph", ofType: "jpg")!
    let stephCurry = UIImage(contentsOfFile: jpgFile)!
    let mlModel = try! await modelStore.getModel().get()
    let results = inferPose(model: mlModel,
                            img: stephCurry.cgImage!,
                            bbox: [60, 26, 280, 571]  // x, y, w, h
    )!
    XCTAssertGreaterThan(averageScore(results: results), 0.65)
    XCTAssertLessThan(averageKeypointError(results: results), 30)
  }
  
  func averageKeypointError(results: Dictionary<Int, [Float]>) -> Double {
    let trueKeypoints = [
      "nose": (197, 93),
      "left_shoulder": (255, 159),
      "left_elbow": (284, 249),
      "left_wrist": (295, 324),
      
      "right_shoulder": (111, 147),
      "right_elbow": (81, 200),
      "right_wrist": (82, 291),
      
      "left_hip": (278, 297),
      "left_knee": (224, 412),
      "left_ankle": (222, 470),
      
      "right_hip": (152, 293),
      "right_knee": (165, 377),
      "right_ankle": (181, 547),
    ]
    
    var numPoints = 0, sumErr = 0.0;
    results.forEach({ (idx, value) in
      let jointName = cocoKeypoints[idx]
      if let (trueX, trueY) = trueKeypoints[jointName] {
        let (x, y) = (Double(value[0] * 480), Double(value[1] * 640))
        let delta = sqrt(pow(x - Double(trueX), 2) + (pow(y - Double(trueY), 2)))
        sumErr += delta
        numPoints += 1
      } else {
        print("Keypoint \(jointName): x=\(value[0]), y=\(value[1]) score=\(value[2])")
      }
    })
    XCTAssertGreaterThan(numPoints, 0)
    let meanErr = sumErr / Double(numPoints)
    return meanErr
  }
  
  func averageScore(results: Dictionary<Int, [Float]>) -> Float {
    let scores = results.values.map({ $0[2] })
    let sum = scores.reduce(0.0) { $0 + $1 }
    return sum / Float(scores.count)
  }
  
  private func getMLPackageBytes() -> Data {
    let zipUrl = Bundle.module.url(
      forResource: "VipnasNoPreprocess",
      withExtension: "mlpackage.zip"
    )!
    return try! FileHandle(forReadingFrom: zipUrl).readDataToEndOfFile()
  }
}
