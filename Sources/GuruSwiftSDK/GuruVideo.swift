import Foundation
import UIKit

public class GuruVideo {
  let apiKey: String
  var schema: [String: Any]!
  var guruEngine: GuruEngine!
  
  public init(apiKey: String, schemaId: String) async throws {
    self.apiKey = apiKey
    
    self.schema = try await self.getSchema(schemaId: schemaId)
    self.guruEngine = GuruEngine(userCode: self.schema["inferenceCode"] as! String)
  }
  
  public func finish() -> GuruAnalysis {
    return GuruAnalysis(result: [:])
  }
  
  public func newFrame(frame: UIImage) -> GuruAnalysis {
    self.guruEngine.processFrame(image: frame)
    return GuruAnalysis(result: [:])
  }
  
  private func getSchema(schemaId: String) async throws -> [String: Any] {
    var request = URLRequest(url: URL(string: "https://api.getguru.fitness/schemas/\(schemaId)")!)
    request.setValue(self.apiKey, forHTTPHeaderField: "x-api-key")

    do {
      let (data, response) = try await URLSession.shared.data(for: request)

      if ((response as? HTTPURLResponse)!.statusCode == 200) {
        return try! JSONSerialization.jsonObject(with: data) as! [String: Any]
      }
      else {
        throw APICallFailed.getSchemaFailed(error: String(decoding: data, as: UTF8.self))
      }
    }
    catch let error as NSError {
      throw APICallFailed.getSchemaFailed(error: error.localizedDescription)
    }
  }
}
