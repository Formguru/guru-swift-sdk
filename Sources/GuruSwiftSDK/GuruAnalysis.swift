import Foundation
import JavaScriptCore

public struct GuruAnalysis {
  public let result: Any?
  public let frameTimestamp: Int
  
  public init(result: Any?, frameTimestamp: Int) {
    self.result = result
    self.frameTimestamp = frameTimestamp
  }
}
