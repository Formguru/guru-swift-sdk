/* Copyright (C) Guru Movement Labs Inc - All Rights Reserved
 * Unauthorized copying of this file, via any medium, is strictly prohibited.
 * Proprietary and confidential.
 */

import Foundation
import CoreML
import os

@available(iOS 14.0, *)
private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier!,
    category: "ModelStore"
)

public struct OnDeviceModel: Codable {
  let modelId: String
  let localPath: URL
}


public struct ModelMetadata: Codable {
  
  enum ModelType: String, Codable {
    case pose = "pose"
  }
  
  let modelId: String
  let modelType: ModelType
  let modelUri: URL
}

public struct ListModelsResponse: Codable {
  let iOS: [ModelMetadata]
}

actor ModelStore {
  
  let USE_LOCAL_MODEL = false
  var model: MLModel? = nil
  
  private func getModelStoreRoot() -> URL {
    let fm = FileManager.default
    let appSupportUrl = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
    let rootUrl = appSupportUrl.appendingPathComponent("GuruOnDeviceModel")
    if (!fm.fileExists(atPath: rootUrl.path)) {
      try! fm.createDirectory(at: rootUrl, withIntermediateDirectories: true)
    }
    return rootUrl
  }
  
  private func listModels() -> [OnDeviceModel] {
    let fm = FileManager.default
    let root = getModelStoreRoot()
    let files = try! fm.contentsOfDirectory(atPath: root.path)
    var results: [OnDeviceModel] = []
    for file in files {
      if file.hasSuffix(".mlmodelc") {
        let url = URL(string: file)!
        let modelId = file.prefix(file.count - url.pathExtension.count - 1)
        results.append(OnDeviceModel(modelId: String(modelId), localPath: root.appendingPathComponent(file)))
      }
    }
    return results
  }
  
  private func downloadFile(url: URL) async throws -> URL {
    let rootUrl = getModelStoreRoot()
    return try await withCheckedThrowingContinuation({ continuation in
      URLSession.shared.downloadTask(with: url, completionHandler: {
        urlOrNil, responseOrNil, errorOrNil in
        let fm = FileManager.default
        
        if let err = errorOrNil {
          continuation.resume(throwing: err)
        } else if let tmpUrl = urlOrNil {
          let outputUrl = rootUrl.appendingPathComponent(url.lastPathComponent)
          if fm.fileExists(atPath: outputUrl.path) {
            try! fm.removeItem(at: outputUrl)
          }
          try! fm.moveItem(at: tmpUrl, to: outputUrl)
          assert(fm.fileExists(atPath: outputUrl.path))
          continuation.resume(returning: outputUrl)
        } else {
          continuation.resume(throwing: PoseModelError.downloadFailed)
        }
      }).resume()
    })
  }
  
  func fetchCurrentModelMetadata(auth: APIAuth) async throws -> ModelMetadata {
    let models = try await getOnDeviceModels(auth: auth)
    return models.first(where: { $0.modelType == .pose })!
  }
  
  private func fetchModel(auth: APIAuth) async -> Result<URL, PoseModelError> {
    let existingModels = listModels()
    guard let modelMeta = try? await fetchCurrentModelMetadata(auth: auth) else {
      if (existingModels.isEmpty) {
        return .failure(PoseModelError.downloadFailed)
      } else {
        let fallback = existingModels.first!.localPath
        if #available(iOS 14.0, *) {
          logger.warning("Failed to fetch latest on-device model, falling back to older model at \(fallback)")
        } else {
          print("Failed to fetch latest on-device model, falling back to older model at \(fallback)")
        }
        return .success(fallback)
      }
    }
    
    let cachedModel = existingModels.first(where: {model in
      model.modelId == modelMeta.modelId
    })
    if cachedModel != nil {
      return .success(cachedModel!.localPath)
    }
    
    // model isn't available locally, we need to fetch and compile it
    let fm = FileManager.default
    let modelZip: URL
    do {
      modelZip = try await downloadFile(url: modelMeta.modelUri)
    } catch {
      return .failure(PoseModelError.downloadFailed)
    }
    assert(fm.fileExists(atPath: modelZip.path))
    let unzipDirectory = try! FileManager.default.url(
      for: .itemReplacementDirectory,
      in: .userDomainMask,
      appropriateFor: modelZip,
      create: true
    )
    try! fm.unzipItem(at: modelZip, to: unzipDirectory)
    let mlPackageDir = try! fm.contentsOfDirectory(atPath: unzipDirectory.path).first(where: { s in
      s.hasSuffix(".mlpackage")
    })!
    let mlPackageUrl = unzipDirectory.appendingPathComponent(mlPackageDir)
    guard let modelUrl = try? MLModel.compileModel(at: mlPackageUrl) else {
      return .failure(PoseModelError.compileFailed)
    }
    let permanentUrl = getModelStoreRoot().appendingPathComponent(
      "\(modelMeta.modelId).\(modelUrl.pathExtension)")
    _ = try! fm.replaceItemAt(permanentUrl, withItemAt: modelUrl)
    
    if #available(iOS 14.0, *) {
      logger.info("Model compiled to \(permanentUrl)")
    }
    return .success(permanentUrl)
  }
  
  public func getModel(auth: APIAuth) async -> Result<MLModel, PoseModelError> {
    if (self.model == nil) {
      let result = await doInitModel(auth: auth)
      switch result {
      case .success(let model):
        self.model = model
      case .failure(let err):
        return .failure(err)
      }
    }
    return .success(self.model!)
  }
  
  private func doInitModel(auth: APIAuth) async -> Result<MLModel, PoseModelError> {
    switch await fetchModel(auth: auth) {
    case .failure(let err):
      return .failure(err)
    case .success(let url):
      if let mlModel = try? MLModel(contentsOf: url) {
        return .success(mlModel)
      } else {
        return .failure(PoseModelError.compileFailed)
      }
    }
  }

  
  private func getOnDeviceModels(auth: APIAuth) async throws -> [ModelMetadata] {
    if let override = getOnDeviceModelOverride() {
      return [override]
    }

    var request = URLRequest(url: URL(string: "https://api.getguru.fitness/mlmodels/ondevice")!)
    request = auth.apply(request: request)
    let (data, response) = try await URLSession.shared.data(for: request)
    let httpResponse = (response as? HTTPURLResponse)!
    guard (httpResponse.statusCode == 200) else {
      throw APICallFailed.getOnDeviceModelsFailed(error: httpResponse.description)
    }
    guard let models: ListModelsResponse = try? JSONDecoder().decode(ListModelsResponse.self, from: data) else {
      throw APICallFailed.getOnDeviceModelsFailed(error: httpResponse.description)
    }
    return models.iOS
  }
  
  private func getOnDeviceModelOverride() -> ModelMetadata? {
    if USE_LOCAL_MODEL {
      return ModelMetadata(
        modelId: "ADDME",
        modelType: .pose,
        modelUri: URL(string: "ADDME")!
      )
    }
    return nil
  }
  
}
