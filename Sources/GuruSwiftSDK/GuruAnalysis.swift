import Foundation
import JavaScriptCore

public struct GuruAnalysis {
  public let result: JSValue?
  public let processResult: Any
  
  public init(result: JSValue?, processResult: Any) {
    self.result = result
    self.processResult = processResult
  }
}
