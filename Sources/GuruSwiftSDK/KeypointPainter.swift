/* Copyright (C) Guru Movement Labs Inc - All Rights Reserved
 * Unauthorized copying of this file, via any medium, is strictly prohibited.
 * Proprietary and confidential.
 */

#if !os(macOS)
import Foundation
import UIKit

public class KeypointPainter {
  
  let context: CGContext
  let width: CGFloat
  let height: CGFloat
  
  public init(context: CGContext, width: CGFloat, height: CGFloat) {
    self.context = context
    self.width = width
    self.height = height
  }
  
  /// Paints a marker at the location of the given keypoint, if it
  /// was found in the inference.
  ///
  /// - Parameter keypoint: The keypoint whose location will be painted.
  /// - Parameter color: The color of the marker. Default is white.
  /// - Parameter size: The size of the marker, in pixels. Default is 20.
  /// - Returns: This same instance of `KeypointPainter`, to allow for call-chaining.
  @discardableResult public func paintKeypoint(
    keypoint: Keypoint,
    color: UIColor = UIColor.white,
    size: Double = 20.0) -> KeypointPainter {
    context.setStrokeColor(color.cgColor)
    context.setFillColor(color.cgColor)
    let framePosition = framePosition(keypoint)
    context.addEllipse(in: CGRect(x: framePosition.x - (size / 2.0), y: framePosition.y - (size / 2.0), width: size, height: size))
    context.drawPath(using: .fillStroke)
    
    return self
  }
  
  /// Paints a marker at the location of 2 given landmarks, if they
  /// exist, and a line connecting them.
  ///
  /// - Parameter from: The first keypoint whose location will be painted.
  /// - Parameter to: The second keypoint whose location will be painted.
  /// - Parameter landmarkColor: The color of the marker. Default is white.
  /// - Parameter connectorColor: The color of the line connecting the landmarks. Default is black.
  /// - Parameter landmarkSize: The size of the marker, in pixels. Default is 20.
  /// - Parameter landmarkSize: The width of the connector, in pixels. Default is 2.
  /// - Returns: This same instance of `KeypointPainter`, to allow for call-chaining.
  @discardableResult public func paintKeypointConnector(
    from: Keypoint,
    to: Keypoint,
    keypointColor: UIColor = UIColor.white,
    connectorColor: UIColor = UIColor.black,
    keypointSize: Double = 20.0,
    connectorWidth: Double = 2.0) -> KeypointPainter {
    context.setStrokeColor(connectorColor.cgColor)
    context.setLineWidth(connectorWidth)
    context.move(to: framePosition(from))
    context.addLine(to: framePosition(to))
    context.strokePath()
    
    paintKeypoint(keypoint: from, color: keypointColor, size: keypointSize)
    paintKeypoint(keypoint: to, color: keypointColor, size: keypointSize)
    
    return self
  }
  
  /// Paints the angle between 2 different keypoints, centered at a third. For example, you can
  /// paint the angle between a shoulder -> hip vector and a shoulder -> elbow vector. You
  /// must also specify whether you want the clockwise or anti-clockwise angle painted.
  /// The painting will include a color highlight of the angle itself, and an overlay showing
  /// the angle in degrees.
  ///
  /// - Parameter center: The keypoint that is connected to the two other keypoints, at which the angle will be centered.
  /// - Parameter from: The first keypoint connected to `center`.
  /// - Parameter to: The second keypoint connected to `center`.
  /// - Parameter clockwise: True if the angle should be counted clockwise between `from` and `to`, false if anti-clockwise.
  /// - Parameter backgroundColor: The color of the painted angle. Default is blue
  /// - Parameter foregroundColor: The color of the text overlay showing the angle in degrees. Default is white.
  /// - Parameter fontSize: The size of the text overlay. Default is 48.
  /// - Returns: This same instance of `KeypointPainter`, to allow for call-chaining.
  @discardableResult public func paintKeypointAngle(
    center: Keypoint,
    from: Keypoint,
    to: Keypoint,
    clockwise: Bool,
    backgroundColor: UIColor = UIColor.blue,
    foregroundColor: UIColor = UIColor.white,
    fontSize: Int = 48) -> KeypointPainter {
    let centerTo = vectorBetweenKeypoints(from: center, to: to)
    let centerFrom = vectorBetweenKeypoints(from: center, to: from)
    let path = UIBezierPath()
    path.move(to: framePosition(center))
    path.addArc(
      withCenter: framePosition(center),
      radius: vectorLength(CGVector(dx: centerTo.dx * self.width, dy: centerTo.dy * self.height)),
      startAngle: angleBetweenVectors(v1: CGVector(dx: 1.0, dy: 0.0), v2: normalizeVector(centerTo)),
      endAngle: angleBetweenVectors(v1: CGVector(dx: 1.0, dy: 0.0), v2: normalizeVector(centerFrom)),
      clockwise: clockwise
    )
    path.close()
    backgroundColor.setFill()
    path.fill()
    
    let angleDegrees = from.angleBetweenRadians(center: center, to: to, clockwise: clockwise)
    paintText(
      position: Keypoint(x: center.x, y: center.y + 0.03),
      text: String(abs(Int(rad2deg(angleDegrees)))) + "º",
      color: foregroundColor,
      fontSize: fontSize,
      rightOfPosition: clockwise
    )
    
    return self
  }
  
  /// Paints text on the image.
  ///
  /// - Parameter position: The position of the text.
  /// - Parameter text: The text to paint.
  /// - Parameter color: The color of the text. Default is white.
  /// - Parameter fontSize: The size of the text. Default is 48.
  /// - Parameter rightOfPosition: True if the text should start at `position`, false if it should end at `position`.
  /// - Returns: This same instance of `KeypointPainter`, to allow for call-chaining.
  @discardableResult public func paintText(
    position: Keypoint,
    text: String,
    color: UIColor = UIColor.white,
    fontSize: Int = 48,
    rightOfPosition: Bool = true) -> KeypointPainter {
    context.saveGState()

    let font = CTFontCreateWithName("SF" as CFString, Double(fontSize), nil)

    let attributedString = NSAttributedString(string: text, attributes: [.font: font, .foregroundColor: color])

    let line = CTLineCreateWithAttributedString(attributedString)

    context.textPosition = position.toScreenPoint(width: self.width, height: self.height)
    if (!rightOfPosition) {
      context.textPosition.x -= CTLineGetImageBounds(line, context).width
    }

    CTLineDraw(line, context)

    context.restoreGState()
    
    return self
  }
  
  fileprivate func framePosition(_ keypoint: Keypoint) -> CGPoint {
    return CGPoint(x: keypoint.x * self.width, y: keypoint.y * self.height)
  }
}

fileprivate func +(left: CGPoint, right: CGPoint) -> CGPoint {
  return CGPoint(x: left.x + right.x, y: left.y + right.y)
}
#endif
