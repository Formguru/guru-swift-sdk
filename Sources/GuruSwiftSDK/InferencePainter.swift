/* Copyright (C) Guru Movement Labs Inc - All Rights Reserved
 * Unauthorized copying of this file, via any medium, is strictly prohibited.
 * Proprietary and confidential.
 */

#if !os(macOS)
import Foundation
import UIKit

public class InferencePainter {
  
  let frame: UIImage
  let inference: FrameInference
  let context: CGContext
  
  public init(frame: UIImage, inference: FrameInference) {
    self.frame = frame
    self.inference = inference
    
    UIGraphicsBeginImageContext(frame.size)
    self.frame.draw(at: CGPoint.zero)
    context = UIGraphicsGetCurrentContext()!
    let textTransform = CGAffineTransform(scaleX: 1.0, y: -1.0)
    context.textMatrix = textTransform
  }
  
  public func cgContext() -> CGContext {
    return context
  }
  
  public func finish() -> UIImage {
    let paintedImage = UIGraphicsGetImageFromCurrentImageContext()
    UIGraphicsEndImageContext()
    return paintedImage!
  }
  
  @discardableResult public func paintLandmark(
    landmark: InferenceLandmark,
    color: UIColor = UIColor.white,
    size: Double = 20.0) -> InferencePainter {
    let keypoint = inference.keypointForLandmark(landmark)
    
    if (keypointIsGood(keypoint)) {
      context.setStrokeColor(color.cgColor)
      context.setFillColor(color.cgColor)
      let framePosition = framePosition(keypoint!)
      context.addEllipse(in: CGRect(x: framePosition.x - (size / 2.0), y: framePosition.y - (size / 2.0), width: size, height: size))
      context.drawPath(using: .fillStroke)
    }
    
    return self
  }
  
  @discardableResult public func paintLandmarkConnector(
    from: InferenceLandmark,
    to: InferenceLandmark,
    landmarkColor: UIColor = UIColor.white,
    connectorColor: UIColor = UIColor.black,
    landmarkSize: Double = 20.0,
    connectorWidth: Double = 2.0) -> InferencePainter {
    let fromKeypoint = inference.keypointForLandmark(from)
    let toKeypoint = inference.keypointForLandmark(to)
    
    if (keypointIsGood(fromKeypoint) && keypointIsGood(toKeypoint)) {
      context.setStrokeColor(connectorColor.cgColor)
      context.setLineWidth(connectorWidth)
      context.move(to: framePosition(fromKeypoint!))
      context.addLine(to: framePosition(toKeypoint!))
      context.strokePath()
    }
    
    paintLandmark(landmark: from, color: landmarkColor, size: landmarkSize)
    paintLandmark(landmark: to, color: landmarkColor, size: landmarkSize)
    
    return self
  }
  
  @discardableResult public func paintLandmarkAngle(
    center: InferenceLandmark,
    from: InferenceLandmark,
    to: InferenceLandmark,
    clockwise: Bool,
    backgroundColor: UIColor = UIColor.blue,
    foregroundColor: UIColor = UIColor.white,
    fontSize: Int = 48) -> InferencePainter {
    let centerKeypoint = inference.keypointForLandmark(center)
    let fromKeypoint = inference.keypointForLandmark(from)
    let toKeypoint = inference.keypointForLandmark(to)
    
    if (keypointIsGood(centerKeypoint) && keypointIsGood(fromKeypoint) && keypointIsGood(toKeypoint)) {
      let centerTo = vector(from: centerKeypoint!, to: toKeypoint!)
      let centerFrom = vector(from: centerKeypoint!, to: fromKeypoint!)
      let path = UIBezierPath()
      path.move(to: framePosition(centerKeypoint!))
      path.addArc(
        withCenter: framePosition(centerKeypoint!),
        radius: vectorLength(CGVector(dx: centerTo.dx * frame.size.width, dy: centerTo.dy * frame.size.height)),
        startAngle: angleBetween(v1: CGVector(dx: 1.0, dy: 0.0), v2: normalizeVector(centerTo)),
        endAngle: angleBetween(v1: CGVector(dx: 1.0, dy: 0.0), v2: normalizeVector(centerFrom)),
        clockwise: clockwise
      )
      path.close()
      backgroundColor.setFill()
      path.fill()
      
      var angleDegrees: Double?
      if (clockwise) {
        angleDegrees = angleBetween(v1: centerTo, v2: centerFrom)
      }
      else {
        angleDegrees = angleBetween(v1: centerFrom, v2: centerTo)
      }
      paintText(
        position: framePosition(centerKeypoint!) + CGPoint(x: 0, y: 40),
        text: String(abs(Int(rad2deg(angleDegrees!)))) + "º",
        color: foregroundColor,
        fontSize: Double(fontSize),
        rightOfPosition: clockwise
      )
    }
    
    return self
  }
  
  @discardableResult public func paintText(position: CGPoint, text: String, color: UIColor, fontSize: Double, rightOfPosition: Bool = true) -> InferencePainter {
    context.saveGState()

    let font = CTFontCreateWithName("SF" as CFString, fontSize, nil)

    let attributedString = NSAttributedString(string: text, attributes: [.font: font, .foregroundColor: color])

    let line = CTLineCreateWithAttributedString(attributedString)

    context.textPosition = position
    if (!rightOfPosition) {
      context.textPosition.x -= CTLineGetImageBounds(line, context).width
    }

    CTLineDraw(line, context)

    context.restoreGState()
    
    return self
  }
  
  fileprivate func angleBetween(v1: CGVector, v2: CGVector) -> Double {
    var angleRadians = atan2(v2.dy, v2.dx) - atan2(v1.dy, v1.dx)
    if angleRadians < 0 {
      angleRadians += 2 * .pi
    }
    return angleRadians
  }
  
  fileprivate func framePosition(_ keypoint: Keypoint) -> CGPoint {
    return CGPoint(x: keypoint.x * frame.size.width, y: keypoint.y * frame.size.height)
  }
  
  fileprivate func keypointIsGood(_ keypoint: Keypoint?) -> Bool {
    return keypoint != nil
  }
  
  fileprivate func normalizeVector(_ vector: CGVector) -> CGVector {
    let vectorLength = vectorLength(vector)
    return CGVector(dx: vector.dx / vectorLength, dy: vector.dy / vectorLength)
  }
  
  fileprivate func rad2deg(_ number: Double) -> Double {
      return number * 180 / .pi
  }
  
  fileprivate func vectorLength(_ vector: CGVector) -> Double {
    return sqrt(pow(vector.dx, 2) + pow(vector.dy, 2))
  }
  
  fileprivate func toVector(_ keypoint: Keypoint) -> CGVector {
    return CGVector(dx: keypoint.x, dy: keypoint.y)
  }
  
  fileprivate func vector(from: Keypoint, to: Keypoint) -> CGVector {
    return CGVector(dx: to.x - from.x, dy: to.y - from.y)
  }
}

fileprivate func +(left: CGPoint, right: CGPoint) -> CGPoint {
  return CGPoint(x: left.x + right.x, y: left.y + right.y)
}
#endif
