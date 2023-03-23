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
  let keypointPainter: KeypointPainter
  
  public init(frame: UIImage, inference: FrameInference) {
    self.frame = frame
    self.inference = inference
    
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
  }
  
  public func cgContext() -> CGContext {
    return context
  }
  
  /// Finalise the painting and return the finished image.
  /// This InferencePainter can no longer be used after this
  /// method has returned.
  ///
  /// - Returns: The render `UIImage` with all modifications included.
  public func finish() -> UIImage {
    let paintedImage = UIGraphicsGetImageFromCurrentImageContext()
    UIGraphicsEndImageContext()
    return paintedImage!
  }
  
  /// Paints a marker at the location of the given landmark, if it
  /// was found in the inference.
  ///
  /// - Parameter landmark: The landmark whose location will be painted.
  /// - Parameter color: The color of the marker. Default is white.
  /// - Parameter size: The size of the marker, in pixels. Default is 20.
  /// - Returns: This same instance of `InferencePainter`, to allow for call-chaining.
  @discardableResult public func paintLandmark(
    landmark: InferenceLandmark,
    color: UIColor = UIColor.white,
    size: Double = 20.0) -> InferencePainter {
    let keypoint = inference.keypointForLandmark(landmark)
    
    if (keypointIsGood(keypoint)) {
      self.keypointPainter.paintKeypoint(keypoint: keypoint!, color: color, size: size)
    }
    
    return self
  }
  
  /// Paints a marker at the location of 2 given landmarks, if they
  /// exist, and a line connecting them.
  ///
  /// - Parameter from: The first landmark whose location will be painted.
  /// - Parameter to: The second landmark whose location will be painted.
  /// - Parameter landmarkColor: The color of the marker. Default is white.
  /// - Parameter connectorColor: The color of the line connecting the landmarks. Default is black.
  /// - Parameter landmarkSize: The size of the marker, in pixels. Default is 20.
  /// - Parameter landmarkSize: The width of the connector, in pixels. Default is 2.
  /// - Returns: This same instance of `InferencePainter`, to allow for call-chaining.
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
      keypointPainter.paintKeypointConnector(
        from: fromKeypoint!,
        to: toKeypoint!,
        keypointColor: landmarkColor,
        connectorColor: connectorColor,
        keypointSize: landmarkSize,
        connectorWidth: connectorWidth
      )
    }
    
    return self
  }
  
  /// Paints the angle between 2 different landmarks, centered at a third. For example, you can
  /// paint the angle between a shoulder -> hip vector and a shoulder -> elbow vector. You
  /// must also specify whether you want the clockwise or anti-clockwise angle painted.
  /// The painting will include a color highlight of the angle itself, and an overlay showing
  /// the angle in degrees.
  ///
  /// - Parameter center: The landmark that is connected to the two other landmarks, at which the angle will be centered.
  /// - Parameter from: The first landmark connected to `center`.
  /// - Parameter to: The second landmark connected to `center`.
  /// - Parameter clockwise: True if the angle should be counted clockwise between `from` and `to`, false if anti-clockwise.
  /// - Parameter backgroundColor: The color of the painted angle. Default is blue
  /// - Parameter foregroundColor: The color of the text overlay showing the angle in degrees. Default is white.
  /// - Parameter fontSize: The size of the text overlay. Default is 48.
  /// - Returns: This same instance of `InferencePainter`, to allow for call-chaining.
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
      self.keypointPainter.paintKeypointAngle(
        center: centerKeypoint!,
        from: fromKeypoint!,
        to: toKeypoint!,
        clockwise: clockwise,
        backgroundColor: backgroundColor,
        foregroundColor: foregroundColor,
        fontSize: fontSize
      )
    }
    
    return self
  }
  
  /// Paints text on the image.
  ///
  /// - Parameter position: The position of the text.
  /// - Parameter text: The text to paint.
  /// - Parameter color: The color of the text. Default is white.
  /// - Parameter fontSize: The size of the text. Default is 48.
  /// - Parameter rightOfPosition: True if the text should start at `position`, false if it should end at `position`.
  /// - Returns: This same instance of `InferencePainter`, to allow for call-chaining.
  @discardableResult public func paintText(
    position: CGPoint,
    text: String,
    color: UIColor = UIColor.white,
    fontSize: Int = 48,
    rightOfPosition: Bool = true) -> InferencePainter {
      self.keypointPainter.paintText(
        position: position,
        text: text,
        color: color,
        fontSize: fontSize,
        rightOfPosition: rightOfPosition
      )
    
    return self
  }
  
  fileprivate func keypointIsGood(_ keypoint: Keypoint?) -> Bool {
    return keypoint != nil
  }
}
#endif
