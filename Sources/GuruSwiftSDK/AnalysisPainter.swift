/* Copyright (C) Guru Movement Labs Inc - All Rights Reserved
 * Unauthorized copying of this file, via any medium, is strictly prohibited.
 * Proprietary and confidential.
 */

#if !os(macOS)
import Foundation
import UIKit

public class AnalysisPainter {
  
  let frame: UIImage
  let context: CGContext
  let keypointPainter: KeypointPainter
  let jointPairs: [[String]]
  
  public init(frame: UIImage) {
    self.frame = frame
    
    UIGraphicsBeginImageContext(frame.size)
    self.frame.draw(at: CGPoint.zero)
    context = UIGraphicsGetCurrentContext()!
    let textTransform = CGAffineTransform(scaleX: 1.0, y: -1.0)
    context.textMatrix = textTransform
    
    self.keypointPainter = KeypointPainter(
      context: self.context,
      width: self.frame.size.width,
      height: self.frame.size.height
    )
    self.jointPairs = [
      ["left_wrist", "left_elbow"],
      ["left_elbow", "left_shoulder"],
      ["left_shoulder", "left_hip"],
      ["left_hip", "left_knee"],
      ["left_knee", "left_ankle"],
      ["left_ankle", "left_heel"],
      ["left_ankle", "left_toe"],
      ["left_heel", "left_toe"],
      ["right_wrist", "right_elbow"],
      ["right_elbow", "right_shoulder"],
      ["right_shoulder", "right_hip"],
      ["right_hip", "right_knee"],
      ["right_knee", "right_ankle"],
      ["right_ankle", "right_heel"],
      ["right_ankle", "right_toe"],
      ["right_heel", "right_toe"],
      ["left_shoulder", "right_shoulder"],
      ["left_hip", "right_hip"],
    ];
  }
  
  public func cgContext() -> CGContext {
    return context
  }
  
  public func finish() -> UIImage {
    let paintedImage = UIGraphicsGetImageFromCurrentImageContext()
    UIGraphicsEndImageContext()
    return paintedImage!
  }
  
  @discardableResult public func boundingBox(
    box: [String: [String: Double]],
    color: [String: Int],
    width: Double) -> AnalysisPainter {
      self.context.setStrokeColor(self.toUIColor(color: color).cgColor)
      
      let topLeft = jsonPointToScreenPoint(box["topLeft"]!)!
      let bottomRight = jsonPointToScreenPoint(box["bottomRight"]!)!
      context.addPath(
        UIBezierPath(rect: CGRect(
          x: topLeft.x,
          y: topLeft.y,
          width: bottomRight.x - topLeft.x,
          height: bottomRight.y - topLeft.y
        )).cgPath
      )
      
      context.setLineWidth(width)
      context.strokePath()
      
      return self
    }
  
  @discardableResult public func skeleton(
    keypoints: [String: [String: Double]],
    lineColor: [String: Int],
    keypointColor: [String: Int],
    lineWidth: Double,
    keypointRadius: Double,
    minKeypointScore: Double = 0.05
  ) -> AnalysisPainter {
    let connectorUIColor = self.toUIColor(color: lineColor)
    let keypointUIColor = self.toUIColor(color: keypointColor)
    
    self.jointPairs.forEach { pair in
      if let joint0JSONKeypoint = keypoints[pair[0]],
         let joint1JSONKeypoint = keypoints[pair[1]],
         let joint0Keypoint = self.jsonPointToKeypoint(joint0JSONKeypoint),
         let joint1Keypoint = self.jsonPointToKeypoint(joint1JSONKeypoint) {
        let minScore = min(joint0Keypoint.score, joint1Keypoint.score)
        if minScore >= minKeypointScore {
          self.keypointPainter.paintKeypointConnector(
            from: joint0Keypoint,
            to: joint1Keypoint,
            keypointColor: keypointUIColor,
            connectorColor: connectorUIColor,
            connectorWidth: lineWidth
          )
        }
      }
    }
    
    return self
  }
  
  private func toUIColor(color: [String: Int]) -> UIColor {
    return UIColor(
      red: CGFloat(color["r"]!),
      green: CGFloat(color["g"]!),
      blue: CGFloat(color["b"]!),
      alpha: CGFloat(color["a"] ?? 1)
    )
  }
  
  private func jsonPointToKeypoint(_ jsonPoint: [String: Double]) -> Keypoint? {
    if let score = jsonPoint["score"] ?? jsonPoint["confidence"],
       let x = jsonPoint["x"],
       let y = jsonPoint["y"] {
      return Keypoint(x: x, y: y, score: score)
    }
    return nil
  }
  
  private func jsonPointToScreenPoint(_ jsonPoint: [String: Double]) -> CGPoint? {
    return self.jsonPointToKeypoint(jsonPoint)?
      .toScreenPoint(width: self.frame.size.width, height: self.frame.size.height)
  }
}
#endif
