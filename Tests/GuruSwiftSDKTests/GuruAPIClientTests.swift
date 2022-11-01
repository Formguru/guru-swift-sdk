//
//  VideoTests.swift
//
//
//  Created by Andrew Stahlman on 10/27/22.
//

import Foundation
import XCTest
@testable import GuruSwiftSDK
import Mocker

final class GuruAPIClientTests: XCTestCase {

  let apiKey = TestUtils.randomString()
  let VIDEO_ID = TestUtils.randomString()
  let FIELD1_VAL = TestUtils.randomString()
  let FIELD2_VAL = TestUtils.randomString()
  let client = GuruAPIClient()
  let videoFileUrl = Bundle.module.url(forResource: "rick-squat", withExtension: "mp4")!

  func testRemoteUploadReturnsVideoId() async throws {
    expectCreateVideoReturns(responseBody: validCreateVideoResponse())

    var numS3Calls = 0
    expectS3ReturnsSuccess(onRequest: {request in
      try! self.assertThatMultipartFieldsAreSet(in: request)
      numS3Calls += 1
    })

    let actualVideoId = try! await client.uploadVideo(videoFile: videoFileUrl, accessToken: "foo-bar-buzz")
    XCTAssertEqual(actualVideoId, VIDEO_ID)
    XCTAssertEqual(numS3Calls, 1)
  }

  func testCreateVideoFailsWithBadAuthToken() async throws {
    expectCreateVideoRejectsWithAuthError()

    var numS3Calls = 0
    expectS3ReturnsSuccess(onRequest: {request in
      numS3Calls += 1
    })

    var gotError = false
    do {
      try await client.uploadVideo(videoFile: videoFileUrl, accessToken: "some-bad-token")
    } catch APICallFailed.createVideoFailed(let error) {
      XCTAssertTrue(error.contains("Authentication failed"))
      gotError = true
    }
    XCTAssert(gotError)
    XCTAssertEqual(numS3Calls, 0)
  }

  func testCreateVideoFailsWith400Status() async throws {
    expectCreateVideoRejectsWithStatus400(message: "File is too big or something")

    var numS3Calls = 0
    expectS3Returns400(onRequest: {_ in
      numS3Calls += 1
    })

    var gotError = false
    do {
      try await client.uploadVideo(videoFile: videoFileUrl, accessToken: "foo-bar-buzz")
    } catch APICallFailed.createVideoFailed(let error) {
      XCTAssertEqual(error, "File is too big or something")
      gotError = true
    }
    XCTAssertTrue(gotError)
    XCTAssertEqual(numS3Calls, 0)
  }

  func testS3UploadFailsWith400Status() async throws {
    let postResponse = validCreateVideoResponse()
    expectCreateVideoReturns(responseBody: postResponse)

    var numS3Calls = 0
    expectS3Returns400(onRequest: { request in
      numS3Calls += 1
    })

    var gotError = false
    do {
      try await client.uploadVideo(videoFile: videoFileUrl, accessToken: "foo-bar-buzz")
    } catch APICallFailed.uploadVideoFailed {
      gotError = true
    }
    XCTAssertTrue(gotError)
    XCTAssertEqual(numS3Calls, 1)
  }

  func expectS3ReturnsSuccess(onRequest: @escaping (URLRequest) -> Void) -> Void {
    var s3Mock = Mock(url: URL(string: "https://fake-s3.amazonaws.com")!,
                      dataType: .json,
                      statusCode: 204,
                      data: [.post : Data()]
    )
    s3Mock.onRequest = { [onRequest] request, _ in
      onRequest(request)
    }
    s3Mock.register()
  }

  func expectS3Returns400(onRequest: @escaping (URLRequest) -> Void) -> Void {
    var s3Mock = Mock(url: URL(string: "https://fake-s3.amazonaws.com")!,
                      dataType: .json,
                      statusCode: 400,
                      data: [.post : Data()]
    )
    s3Mock.onRequest = { [onRequest] request, _ in
      onRequest(request)
    }
    s3Mock.register()
  }

  func expectCreateVideoReturns(responseBody: Data) -> Void {
    Mock(
      url: URL(string: "https://api.getguru.fitness/videos")!,
      dataType: .json,
      statusCode: 200,
      data: [.post : responseBody]
    ).register()
  }

  func expectCreateVideoRejectsWithStatus400(message: String) -> Void {
    Mock(
      url: URL(string: "https://api.getguru.fitness/videos")!,
      dataType: .json,
      statusCode: 400,
      data: [.post : message.data(using: .utf8)! ]
    ).register()
  }

  func expectCreateVideoRejectsWithAuthError() -> Void {
    Mock(
      url: URL(string: "https://api.getguru.fitness/videos")!,
      dataType: .json,
      statusCode: 401,
      data: [.post : "Authentication failed".data(using: .utf8)! ]
    ).register()
  }

  private func assertThatMultipartFieldsAreSet(in request: URLRequest) throws {
    let expectedLines = [
      "Content-Disposition: form-data; name=\"field1\"\r\n\r\n\(FIELD1_VAL)",
      "Content-Disposition: form-data; name=\"field2\"\r\n\r\n\(FIELD2_VAL)",
      "Content-Disposition: form-data; name=\"file\"; filename=\"rick-squat.mp4\"\r\nContent-Type: video/quicktime",
    ]
    guard let strBody = self.readHttpBodyPrefix(request: request, numBytes: 1024) else {
      XCTFail("Failed to read HTTP body")
      return
    }
    for line in expectedLines {
      XCTAssert(strBody.contains(line), "Expected \(line) to be present")
    }
  }

  private func readHttpBodyPrefix(request: URLRequest, numBytes: Int) -> String? {
    guard let bodyStream = request.httpBodyStream else {
      return nil
    }
    bodyStream.open()
    let bufferSize: Int = 128
    let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
    var data = Data()

    while bodyStream.hasBytesAvailable {
      let readData = bodyStream.read(buffer, maxLength: bufferSize)
      data.append(buffer, count: readData)
    }
    let strBody = String(decoding: data.subdata(in: 0..<numBytes), as: UTF8.self)
    buffer.deallocate()
    bodyStream.close()
    return strBody
  }

  func validCreateVideoResponse() -> Data {
    return try! JSONSerialization.data(withJSONObject: [
      "id": VIDEO_ID,
      "url": "https://fake-s3.amazonaws.com",
      "fields": [
        "field1": FIELD1_VAL,
        "field2": FIELD2_VAL,
      ]
    ])
  }
}
