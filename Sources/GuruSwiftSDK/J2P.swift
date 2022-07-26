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

public struct Keypoint {
  let x: Double
  let y: Double
  let score: Double
}

public struct FrameInference {
  let keypoints: [Int: Keypoint]?
  let timestamp: Date
  let secondsSinceStart: Double
  let frameIndex: Int

  func keypointForLandmark(landmark: InferenceLandmark) -> Keypoint? {
    return keypoints?[cocoLabelToIdx[landmark.rawValue]!]
  }
  
  func keypointForCoco(landmark: InferenceLandmark) -> Keypoint? {
    return keypoints?[cocoLabelToIdx[landmark.rawValue]!]
  }
}
