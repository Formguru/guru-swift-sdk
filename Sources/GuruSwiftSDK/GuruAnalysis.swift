import Foundation
import JavaScriptCore

public struct GuruAnalysis {
  public let result: Any?
  public let processResult: Any
  
  public init(result: Any?, processResult: Any) {
    self.result = result
    self.processResult = processResult
  }
}
