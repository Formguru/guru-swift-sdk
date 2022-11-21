/* Copyright (C) Guru Movement Labs Inc - All Rights Reserved
 * Unauthorized copying of this file, via any medium, is strictly prohibited.
 * Proprietary and confidential.
 */

import Foundation

public typealias VideoId = String

public class GuruAPIClient {

  let auth: APIAuth

  public init(auth: APIAuth) {
    self.auth = auth
  }

  public func overlays(videoId: VideoId) async throws -> [OverlayType: URL]? {
    var request = URLRequest(url: URL(string: "https://api.getguru.fitness/videos/\(videoId)/overlays")!)
    request = auth.apply(request: request)

    do {
      let (data, response) = try await URLSession.shared.data(for: request)

      if ((response as? HTTPURLResponse)!.statusCode == 200) {
        let json = try! JSONSerialization.jsonObject(with: data) as! [String: Any]

        var overlays : [OverlayType: URL] = [:]
        for (overlayType, overlayData) in json {
          if (overlayType == "status") {
            if (overlayData as? String == "Pending") {
              return nil
            }
          }
          else {
            let overlayDictionary = overlayData as! [String: String]
            if ((overlayDictionary["status"]!) == "Pending") {
              return nil
            }
            overlays[OverlayType(rawValue: overlayType)!] = URL(string: overlayDictionary["uri"]!)
          }
        }

        return overlays
      }
      else {
        throw APICallFailed.getOverlaysFailed(error: String(decoding: data, as: UTF8.self))
      }
    }
    catch let error as NSError {
      throw APICallFailed.getOverlaysFailed(error: error.localizedDescription)
    }
  }
 
  public func uploadVideo(videoFile: URL, domain: String? = nil, activity: String? = nil, repCount: Int? = nil, videoId: VideoId? = nil) async throws -> VideoId {

    // TODO: check that the videoFile is a .mov?
    let videoBytes = try! Data(contentsOf: videoFile)
    let numBytes = videoBytes.count
    let fileName = videoFile.lastPathComponent

    if (videoId == nil) {
      var request = URLRequest(url: URL(string: "https://api.getguru.fitness/videos")!)
      request.httpMethod = "POST"
      request.setValue("application/json", forHTTPHeaderField: "Content-Type")
      request = auth.apply(request: request)
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

      return try await uploadFile(uploadInfoResponse: response, uploadInfoData: data, videoBytes: videoBytes, fileName: fileName)
    }
    else {
      var request = URLRequest(url: URL(string: "https://api.getguru.fitness/videos/\(videoId!)/video")!)
      request.httpMethod = "PUT"
      request.setValue("application/json", forHTTPHeaderField: "Content-Type")
      request = auth.apply(request: request)
      let body: [String: Any] = [
        "extension": (fileName as NSString).pathExtension,
        "size": numBytes,
      ]
      request.httpBody = try! JSONSerialization.data(withJSONObject: body)
      let (data, response) = try! await URLSession.shared.data(for: request)

      return try await uploadFile(uploadInfoResponse: response, uploadInfoData: data, videoBytes: videoBytes, fileName: fileName)
    }
  }

  private func uploadFile(uploadInfoResponse: URLResponse, uploadInfoData: Data, videoBytes: Data, fileName: String) async throws -> VideoId {
    guard let httpResponse = (uploadInfoResponse as? HTTPURLResponse),
          httpResponse.isSuccess() else {
      throw APICallFailed.createVideoFailed(error: String(decoding: uploadInfoData, as: UTF8.self))
    }
    guard let json = try! JSONSerialization.jsonObject(with: uploadInfoData) as? [String: Any] else {
      throw APICallFailed.createVideoFailed(error: String(decoding: uploadInfoData, as: UTF8.self))
    }
    let fileUploadUrl = URL(string: json["url"] as! String)!
    let fields = json["fields"] as! [String: String]
    let videoId = json["id"] as! String

    let request = MultipartFormDataRequest(url: fileUploadUrl)
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
    
    return videoId
  }
}


extension HTTPURLResponse {
  func isSuccess() -> Bool {
    return (Double(self.statusCode) / 100.0).rounded(.down) == 2
  }
}
