//
//  File.swift
//  
//
//  Created by Andrew Stahlman on 11/29/22.
//

import Foundation
import XCTest
@testable import GuruSwiftSDK
import Mocker

final class ModelStoreTests: XCTestCase {
  
  let modelStore = ModelStore()
    
  func testGetOnDeviceModelsReturnsList() async throws {
    let modelUri = URL(string: "http://some-s3-bucket.s3.amazonaws.com")!
    expectGetOnDeviceModelsReturns(models: [ModelMetadata(modelId: "123", modelType: .pose, modelUri: modelUri)])
    let model = try! await modelStore.fetchCurrentModelMetadata(auth: APIKeyAuth(apiKey: "foo-bar-buzz"))
    XCTAssertEqual(model.modelId, "123")
    XCTAssertEqual(model.modelUri, modelUri)
  }
  
  func expectGetOnDeviceModelsReturns(models: [ModelMetadata]) {
    let response = ListModelsResponse(iOS: models)
    let responseBody = try! JSONEncoder().encode(response)
    Mock(
      url: URL(string: "https://api.getguru.fitness/mlmodels/ondevice")!,
      dataType: .json,
      statusCode: 200,
      data: [.get : responseBody]
    ).register()
  }
  
}
