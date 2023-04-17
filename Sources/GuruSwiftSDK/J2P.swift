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

public enum UserFacing {
  case right
  case left
  case toward
  case other
}

public struct Keypoint: Equatable {
  public let x: Double
  public let y: Double
  public let score: Double

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
}

public class FrameInference {
  let previousFrame: FrameInference?
  let rawKeypoints: [Int: Keypoint]?
  let smoothKeypoints: [Int: Keypoint]?
  let timestamp: Date
  let secondsSinceStart: Double
  let frameIndex: Int
  
  public init(keypoints: [Int: Keypoint]?, timestamp: Date, secondsSinceStart: Double, frameIndex: Int, previousFrame: FrameInference?) {
    self.rawKeypoints = keypoints
    self.timestamp = timestamp
    self.secondsSinceStart = secondsSinceStart
    self.frameIndex = frameIndex
    self.previousFrame = previousFrame
    
    if (previousFrame == nil || previousFrame?.smoothKeypoints == nil) {
      self.smoothKeypoints = rawKeypoints
    }
    else if (rawKeypoints != nil) {
      self.smoothKeypoints = FrameInference.smoothedKeypoints(keypoints: rawKeypoints!, previousFrame: previousFrame!)
    }
    else {
      self.smoothKeypoints = nil
    }
  }

  public func keypointForLandmark(_ landmark: InferenceLandmark) -> Keypoint? {
    return smoothKeypoints?[cocoLabelToIdx[landmark.rawValue]!]
  }
  
  public func userFacing() -> UserFacing {
    let nose = keypointForLandmark(InferenceLandmark.nose)
    if (nose == nil) {
      return UserFacing.other
    }
    else {
      let leftEar = keypointForLandmark(InferenceLandmark.leftEar)
      let rightEar = keypointForLandmark(InferenceLandmark.rightEar)
      if (leftEar != nil && rightEar != nil) {
        if (nose!.x < leftEar!.x && nose!.x > rightEar!.x) {
          return UserFacing.toward
        }
        else if (nose!.x < leftEar!.x && nose!.x < rightEar!.x) {
          return UserFacing.right
        }
        else if (nose!.x > leftEar!.x && nose!.x > rightEar!.x) {
          return UserFacing.left
        }
        else {
          return UserFacing.other
        }
      }
      else {
        return UserFacing.other
      }
    }
  }
  
  private static func smoothedKeypoints(keypoints: [Int: Keypoint], previousFrame: FrameInference) -> [Int: Keypoint] {
    let currentFrameWeight = 0.25

    var smoothedKeypoints = [Int: Keypoint]()
    for nextLandmark in InferenceLandmark.allCases {
      let previousKeypoint = previousFrame.keypointForLandmark(nextLandmark);
      let landmarkIndex = cocoLabelToIdx[nextLandmark.rawValue]!
      let currentKeypoint = keypoints[landmarkIndex];
      
      let minScore = 0.01
      if (previousKeypoint == nil || previousKeypoint!.score < minScore) {
        smoothedKeypoints[landmarkIndex] = currentKeypoint
      } else if (currentKeypoint == nil || currentKeypoint!.score < minScore) {
        smoothedKeypoints[landmarkIndex] = previousKeypoint
      } else {
        smoothedKeypoints[landmarkIndex] = Keypoint(
          x: (1 - currentFrameWeight) * previousKeypoint!.x + currentFrameWeight * currentKeypoint!.x,
          y: (1 - currentFrameWeight) * previousKeypoint!.y + currentFrameWeight * currentKeypoint!.y,
          score: (1 - currentFrameWeight) * previousKeypoint!.score + currentFrameWeight * currentKeypoint!.score
        )
      }
    }
    
    return smoothedKeypoints
  }
}
