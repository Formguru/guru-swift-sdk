protocol APIAuth {
  /**
   Applies this authorization method to the given request.

   Returns the same URLRequest, to allow method chaining.
   */
  func apply(request: URLRequest) -> URLRequest
}

class AccessTokenAuth : APIAuth {
  let accessToken: String

  public init(accessToken: String) {
    self.accessToken = accessToken
  }

  func apply(request: URLRequest) -> URLRequest {
    request.setValue("Bearer \(self.accessToken)", forHTTPHeaderField: "Authorization")
    return request
  }
}

class APIKeyAUth : APIAuth {
  let apiKey: String

  public init(apiKey: String) {
    self.apiKey = apiKey
  }

  func apply(request: URLRequest) -> URLRequest {
    request.setValue(self.apiKey, forHTTPHeaderField: "x-api-key")
    return request
  }
}
