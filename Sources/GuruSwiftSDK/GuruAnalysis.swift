import Foundation
import JavaScriptCore

public struct GuruAnalysis {
  public let result: Any?
  public let processResult: Any
  public let frameTimestamp: Int
  
  public init(result: Any?, processResult: Any, frameTimestamp: Int) {
    self.result = result
    self.processResult = processResult
    self.frameTimestamp = frameTimestamp
  }
}
