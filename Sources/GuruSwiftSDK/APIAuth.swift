import Foundation

public protocol APIAuth {
  /**
   Applies this authorization method to the given request.

   Returns the same URLRequest, to allow method chaining.
   */
  @discardableResult
  func apply(request: URLRequest) -> URLRequest
}

public class AccessTokenAuth : APIAuth {
  let accessToken: String

  public init(accessToken: String) {
    self.accessToken = accessToken
  }

  public func apply(request: URLRequest) -> URLRequest {
    var requestCopy = request
    requestCopy.setValue("Bearer \(self.accessToken)", forHTTPHeaderField: "Authorization")
    return requestCopy
  }
}

public class APIKeyAuth : APIAuth {
  let apiKey: String

  public init(apiKey: String) {
    self.apiKey = apiKey
  }

  public func apply(request: URLRequest) -> URLRequest {
    var requestCopy = request
    requestCopy.setValue(self.apiKey, forHTTPHeaderField: "x-api-key")
    return requestCopy
  }
}
