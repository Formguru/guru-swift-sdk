import Foundation

public struct GuruAnalysis {
  public init(result: [String: Any]) {
    self.result = result
  }
  
  public let result: [String: Any]
}
