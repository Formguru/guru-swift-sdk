import Foundation


public func angleBetweenVectors(v1: CGVector, v2: CGVector) -> Double {
  var angleRadians = atan2(v2.dy, v2.dx) - atan2(v1.dy, v1.dx)
  if angleRadians < 0 {
    angleRadians += 2 * .pi
  }
  return angleRadians
}

public func normalizeVector(_ vector: CGVector) -> CGVector {
  let vectorLength = vectorLength(vector)
  return CGVector(dx: vector.dx / vectorLength, dy: vector.dy / vectorLength)
}

public func rad2deg(_ number: Double) -> Double {
    return number * 180 / .pi
}

public func vectorLength(_ vector: CGVector) -> Double {
  return sqrt(pow(vector.dx, 2) + pow(vector.dy, 2))
}

public func keypointToVector(_ keypoint: Keypoint) -> CGVector {
  return CGVector(dx: keypoint.x, dy: keypoint.y)
}

public func vectorBetweenKeypoints(from: Keypoint, to: Keypoint) -> CGVector {
  return CGVector(dx: to.x - from.x, dy: to.y - from.y)
}
