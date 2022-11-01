/* Copyright (C) Guru Movement Labs Inc - All Rights Reserved
 * Unauthorized copying of this file, via any medium, is strictly prohibited.
 * Proprietary and confidential.
 */

import Foundation

public typealias VideoId = String

public class GuruAPIClient {

  public init() { }
 
  public func uploadVideo(videoFile: URL, accessToken: String, domain: String? = nil, activity: String? = nil, repCount: Int? = nil) async throws -> VideoId {

    // TODO: check that the videoFile is a .mov?
    let videoBytes = try! Data(contentsOf: videoFile)
    let numBytes = videoBytes.count
    let fileName = videoFile.lastPathComponent

    var request = URLRequest(url: URL(string: "https://api.getguru.fitness/videos")!)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
    var body: [String: Any] = [
      "filename": fileName,
      "size": numBytes,
    ]
    if activity != nil {
      body["activity"] = activity
    }
    if domain != nil {
      body["domain"] = domain
    }
    if repCount != nil {
      body["repCount"] = repCount
    }
    request.httpBody = try! JSONSerialization.data(withJSONObject: body)
    let (data, response) = try! await URLSession.shared.data(for: request)

    guard let httpResponse = (response as? HTTPURLResponse),
          httpResponse.isSuccess() else {
      throw APICallFailed.createVideoFailed(error: String(decoding: data, as: UTF8.self))
    }
    guard let json = try! JSONSerialization.jsonObject(with: data) as? [String: Any] else {
      throw APICallFailed.createVideoFailed(error: String(decoding: data, as: UTF8.self))
    }
    let fileUploadUrl = URL(string: json["url"] as! String)!
    let fields = json["fields"] as! [String: String]
    let videoId = json["id"] as! String
    try await uploadFile(to: fileUploadUrl, videoBytes: videoBytes, fileName: fileName, fields: fields)
    return videoId
  }

  private func uploadFile(to url: URL, videoBytes: Data, fileName: String, fields: [String: String]) async throws -> Void {
    let request = MultipartFormDataRequest(url: url)
    for (k, v) in fields {
      request.addTextField(named: k, value: v)
    }
    request.addFile(fileName: fileName, data: videoBytes)

    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
      URLSession.shared.dataTask(with: request, completionHandler: { (data, urlResponse, error) in
        if let error = error {
          continuation.resume(throwing: APICallFailed.uploadVideoFailed(error: error.localizedDescription))
          return
        }
        guard let httpResponse = urlResponse as? HTTPURLResponse else {
          continuation.resume(throwing: APICallFailed.uploadVideoFailed(error: "No response from S3"))
          return
        }
        if (httpResponse.isSuccess()) {
          continuation.resume()
        } else {
          continuation.resume(throwing: APICallFailed.uploadVideoFailed(error: "S3 returned HTTP \(httpResponse.statusCode)"))
        }
      }).resume()
    }
  }
}


extension HTTPURLResponse {
  func isSuccess() -> Bool {
    return (Double(self.statusCode) / 100.0).rounded(.down) == 2
  }
}
