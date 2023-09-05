/* Copyright (C) Guru Movement Labs Inc - All Rights Reserved
 * Unauthorized copying of this file, via any medium, is strictly prohibited.
 * Proprietary and confidential.
 */

import Foundation

let cocoKeypoints = [
  "nose",
  "left_eye",
  "right_eye",
  "left_ear",
  "right_ear",
  "left_shoulder",
  "right_shoulder",
  "left_elbow",
  "right_elbow",
  "left_wrist",
  "right_wrist",
  "left_hip",
  "right_hip",
  "left_knee",
  "right_knee",
  "left_ankle",
  "right_ankle",
]
let cocoLabelToIdx = Dictionary(uniqueKeysWithValues: cocoKeypoints.enumerated().map { ($1, $0) })

let cocoPairs = [
  ["left_shoulder", "right_shoulder"],
  ["left_shoulder", "left_hip"],
  ["left_hip", "left_knee"],
  ["left_knee", "left_ankle"],
  ["right_shoulder", "right_hip"],
  ["right_hip", "right_knee"],
  ["right_knee", "right_ankle"],
  ["left_hip", "right_hip"],
  ["left_shoulder", "left_elbow"],
  ["left_elbow", "left_wrist"],
  ["right_shoulder", "right_elbow"],
  ["right_elbow", "right_wrist"],
];

public enum InferenceLandmark: String, CaseIterable {
  case leftEye = "left_eye"
  case rightEye = "right_eye"
  case leftEar = "left_ear"
  case rightEar = "right_ear"
  case nose = "nose"
  case leftShoulder = "left_shoulder"
  case rightShoulder = "right_shoulder"
  case leftElbow = "left_elbow"
  case rightElbow = "right_elbow"
  case leftWrist = "left_wrist"
  case rightWrist = "right_wrist"
  case leftHip = "left_hip"
  case rightHip = "right_hip"
  case leftKnee = "left_knee"
  case rightKnee = "right_knee"
  case leftAnkle = "left_ankle"
  case rightAnkle = "right_ankle"
}

public struct Keypoint: Equatable {
  public let x: Double
  public let y: Double
  public let score: Double
  
  public init(x: Double, y: Double, score: Double = 1.0) {
    self.x = x
    self.y = y
    self.score = score
  }

  static public func ==(lhs: Keypoint, rhs: Keypoint) -> Bool {
    return lhs.x == rhs.x && lhs.y == rhs.y && lhs.score == rhs.score
  }

  public func angleBetweenRadians(center: Keypoint, to: Keypoint, clockwise: Bool) -> Double {
    let centerTo = vectorBetweenKeypoints(from: center, to: to)
    let centerFrom = vectorBetweenKeypoints(from: center, to: self)

    if (clockwise) {
      return angleBetweenVectors(v1: centerTo, v2: centerFrom)
    }
    else {
      return angleBetweenVectors(v1: centerFrom, v2: centerTo)
    }
  }
  
  public func toScreenPoint(width: CGFloat, height: CGFloat) -> CGPoint {
    return CGPoint(x: self.x * width, y: self.y * height)
  }
}
