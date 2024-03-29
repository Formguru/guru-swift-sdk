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
    borderColor: [String: Int]? = nil,
    backgroundColor: [String: Int]? = nil,
    width: Double? = nil,
    alpha: Double = 1.0) -> AnalysisPainter {
    if (borderColor != nil) {
      self.toUIColor(color: borderColor!, alpha: alpha).setStroke()
    }
    if (backgroundColor != nil) {
      self.toUIColor(color: backgroundColor!, alpha: alpha).setFill()
    }
    
    let topLeft = jsonPointToScreenPoint(box["topLeft"]!)!
    let bottomRight = jsonPointToScreenPoint(box["bottomRight"]!)!
    context.addRect(CGRect(
      x: topLeft.x,
      y: topLeft.y,
      width: bottomRight.x - topLeft.x,
      height: bottomRight.y - topLeft.y
    ))
    
    if let width = width {
      context.setLineWidth(width)
    }

    if let backgroundColor = backgroundColor {
      context.fillPath()
    }
    else {
      context.strokePath()
    }
    
    return self
  }
  
  @discardableResult public func circle(
    center: [String: Double],
    radius: Int,
    color: [String: Int],
    params: [String: Any]?
  ) -> AnalysisPainter {
    let uiColor = self.toUIColor(color: color, alpha: params?["alpha"] as? Double ?? 1.0)
    
    self.context.setFillColor(uiColor.cgColor)
    self.context.setStrokeColor(uiColor.cgColor)
    self.context.setLineWidth(params?["width"] as? Double ?? 2.0)

    let centerScreen = jsonPointToScreenPoint(center)!
    self.context.addEllipse(in: CGRect(
      x: Int(centerScreen.x) - radius,
      y: Int(centerScreen.y) - radius,
      width: radius * 2, height: radius * 2
    ))

    if (params?["filled"] as? Bool ?? true) {
      self.context.drawPath(using: .fillStroke)
    }
    else {
      self.context.drawPath(using: .stroke)
    }
    
    return self
  }
  
  @discardableResult public func line(
    from: [String: Double],
    to: [String: Double],
    color: [String: Int],
    params: [String: Any]?
  ) -> AnalysisPainter {
    let uiColor = self.toUIColor(color: color, alpha: params?["alpha"] as? Double ?? 1.0)
    
    self.keypointPainter.paintKeypointConnector(
      from: self.jsonPointToKeypoint(from)!,
      to: self.jsonPointToKeypoint(to)!,
      keypointColor: uiColor,
      connectorColor: uiColor,
      keypointSize: 0,
      connectorWidth: params?["width"] as? Double ?? 2.0
    )
    
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
  
  @discardableResult public func text(
    text: String,
    position: [String: Double],
    color: [String: Int],
    params: [String: Any]?
  ) -> AnalysisPainter {
    let alpha = params?["alpha"] as? Double ?? 1.0
    let uiColor = self.toUIColor(color: color, alpha: alpha)
    
    var paddingX = 0.0, paddingY = 0.0
    if let padding = params?["padding"] as? Int {
      paddingX = Double(padding) / self.frame.size.width
      paddingY = Double(padding) / self.frame.size.height
    }
    
    let fontSize = params?["fontSize"] as? Int ?? 24
    
    if let backgroundColor = params?["backgroundColor"] as? [String: Int] {
      let textSize = text.size(withAttributes: [
        .font: self.keypointPainter.getFont(fontSize: fontSize),
      ])
      self.boundingBox(
        box: [
          "topLeft": position,
          "bottomRight": [
            "x": position["x"]! + (textSize.width / self.frame.size.width) + paddingX * 2,
            "y": position["y"]! + (textSize.height / self.frame.size.height) + paddingY * 2
          ],
        ],
        backgroundColor: backgroundColor,
        alpha: alpha
      )
    }
    
    let textPosition = self.jsonPointToKeypoint([
      "x": position["x"]! + paddingX,
      "y": position["y"]! + paddingY
    ])!
    self.keypointPainter.paintText(
      position: textPosition,
      text: text,
      color: uiColor,
      fontSize: fontSize
    )
    
    return self
  }
  
  @discardableResult public func triangle(
    a: [String: Double],
    b: [String: Double],
    c: [String: Double],
    params: [String: Any]?
  ) -> AnalysisPainter {
    let path = UIBezierPath()
    let aScreenpoint = self.jsonPointToScreenPoint(a)!
    path.move(to: CGPoint(x: aScreenpoint.x, y: aScreenpoint.y))
    let bScreenpoint = self.jsonPointToScreenPoint(b)!
    path.addLine(to: CGPoint(x: bScreenpoint.x, y: bScreenpoint.y))
    let cScreenpoint = self.jsonPointToScreenPoint(c)!
    path.addLine(to: CGPoint(x: cScreenpoint.x, y: cScreenpoint.y))
    path.close()
    context.addPath(path.cgPath)
    
    let alpha = params?["alpha"] as? Double ?? 1.0
    if let backgroundColor = params?["backgroundColor"] as? [String: Int] {
      self.toUIColor(color: backgroundColor, alpha: alpha).setFill()
      context.fillPath()
    }
    else if let borderColor = params?["borderColor"] as? [String: Int] {
      self.toUIColor(color: borderColor, alpha: alpha).setStroke()
      context.strokePath()
    }
    
    return self
  }
  
  private func toUIColor(color: [String: Int], alpha: Double = 1.0) -> UIColor {
    return UIColor(
      red: CGFloat(Double(color["r"]!) / 255.0),
      green: CGFloat(Double(color["g"]!) / 255.0),
      blue: CGFloat(Double(color["b"]!) / 255.0),
      alpha: alpha
    )
  }
  
  private func jsonPointToKeypoint(_ jsonPoint: [String: Double]) -> Keypoint? {
    if let x = jsonPoint["x"],
       let y = jsonPoint["y"] {
      let score = jsonPoint["score"] ?? jsonPoint["confidence"] ?? 1.0
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
