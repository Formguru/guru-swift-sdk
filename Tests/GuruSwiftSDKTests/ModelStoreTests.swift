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
    let model = try! await modelStore.getLatestModelMetadata(auth: APIKeyAuth(apiKey: "foo"), type: ModelMetadata.ModelType.pose)
    XCTAssertEqual(model.modelId, "123")
    XCTAssertEqual(model.modelUri, modelUri)
  }
  
  func testFallbackIfFetchingModelsFails() async throws {
    let modelUri = URL(string: "https://formguru-datasets.s3.us-west-2.amazonaws.com/on-device/20230620/vipnas.onnx")!
    expectGetOnDeviceModelsReturns(models: [
      ModelMetadata(modelId: "123", modelType: .pose, modelUri: modelUri)
    ])

    // Note: for now we're actually fetching the model from S3
    Mocker.ignore(modelUri)
    
    let model = try! await modelStore.getModel(auth: APIKeyAuth(apiKey: "foo"), type: ModelMetadata.ModelType.pose).get()
    Mock(
      url: URL(string: "https://api.getguru.fitness/mlmodels/ondevice?sdkVersion=2.0.0")!,
      dataType: .json,
      statusCode: 401,
      data: [.get : Data()]
    ).register()
    let sameModel = try await ModelStore().getModel(auth: APIKeyAuth(apiKey: "foo"), type: ModelMetadata.ModelType.pose).get()
  }
  
  func expectGetOnDeviceModelsReturns(models: [ModelMetadata]) {
    let response = ListModelsResponse(iOS: models)
    let responseBody = try! JSONEncoder().encode(response)
    Mock(
      url: URL(string: "https://api.getguru.fitness/mlmodels/ondevice?sdkVersion=2.0.0")!,
      dataType: .json,
      statusCode: 200,
      data: [.get : responseBody]
    ).register()
  }
}
