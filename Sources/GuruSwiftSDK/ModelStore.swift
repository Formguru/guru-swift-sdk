/* Copyright (C) Guru Movement Labs Inc - All Rights Reserved
 * Unauthorized copying of this file, via any medium, is strictly prohibited.
 * Proprietary and confidential.
 */

import Foundation
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

public enum PoseModelError: Error {
  case downloadFailed
  case compileFailed
}


public struct ModelMetadata: Codable {
  
  enum ModelType: String, Codable {
    case object = "object"
    case person = "person"
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
  var modelByType: [ModelMetadata.ModelType: URL] = [ : ]
  
  public func getLatestModelMetadata(auth: APIAuth, type: ModelMetadata.ModelType) async throws -> ModelMetadata {
    let models = try await getOnDeviceModels(auth: auth)
    return models.first(where: { $0.modelType == type })!
  }
  
  public func getModel(auth: APIAuth, type: ModelMetadata.ModelType) async -> Result<URL, PoseModelError> {
    if let model = modelByType[type] {
      return .success(model)
    }
    let result = await doInitModel(auth: auth, type: type)
    switch result {
    case .success(let model):
      self.modelByType[type] = model
      return .success(model)
    case .failure(let err):
      return .failure(err)
    }
  }
  
  private func getModelStoreRoot() -> URL {
    let fm = FileManager.default
    let appSupportUrl = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
    let rootUrl = appSupportUrl.appendingPathComponent("GuruOnDeviceModel")
    if (!fm.fileExists(atPath: rootUrl.path)) {
      try! fm.createDirectory(at: rootUrl, withIntermediateDirectories: true)
    }
    return rootUrl
  }
  
  private func listLocalModels() -> [OnDeviceModel] {
    let fm = FileManager.default
    let root = getModelStoreRoot()
    let files = try! fm.contentsOfDirectory(atPath: root.path)
    var results: [OnDeviceModel] = []
    for file in files {
      if file.hasSuffix(".onnx") {
        let url = URL(string: file)!
        let modelId = file.prefix(file.count - url.pathExtension.count - 1)
        results.append(OnDeviceModel(modelId: String(modelId), localPath: root.appendingPathComponent(file)))
      }
    }
    return results
  }
  
  private func downloadModel(metadata: ModelMetadata) async throws -> URL {
    if #available(iOS 14.0, *) {
      logger.info("Downloading model from \(metadata.modelUri.absoluteString)")
    }
    
    let rootUrl = getModelStoreRoot()
    return try await withCheckedThrowingContinuation({ continuation in
      URLSession.shared.downloadTask(with: metadata.modelUri, completionHandler: {
        urlOrNil, responseOrNil, errorOrNil in
        let fm = FileManager.default
        
        if let err = errorOrNil {
          continuation.resume(throwing: err)
        } else if let tmpUrl = urlOrNil {
          let outputUrl = rootUrl.appendingPathComponent("\(metadata.modelId).\(metadata.modelUri.pathExtension)")
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
  
  private func fetchModel(auth: APIAuth, type: ModelMetadata.ModelType) async -> Result<URL, PoseModelError> {
    let localModels = listLocalModels()
    guard let latestModelMetadata = try? await getLatestModelMetadata(auth: auth, type: type) else {
      if (localModels.isEmpty) {
        return .failure(PoseModelError.downloadFailed)
      } else {
        let fallback = localModels.first!.localPath
        if #available(iOS 14.0, *) {
          logger.warning("Failed to fetch latest on-device model, falling back to older model at \(fallback)")
        } else {
          print("Failed to fetch latest on-device model, falling back to older model at \(fallback)")
        }
        return .success(fallback)
      }
    }

    let cachedModel = localModels.first(where: {model in
      model.modelId == latestModelMetadata.modelId
    })
    if cachedModel != nil {
      return .success(cachedModel!.localPath)
    }
    
    let modelDownloadUrl: URL
    do {
      modelDownloadUrl = try await downloadModel(metadata: latestModelMetadata)
    } catch {
      return .failure(PoseModelError.downloadFailed)
    }
    
    return .success(modelDownloadUrl)
  }
  
  private func doInitModel(auth: APIAuth, type: ModelMetadata.ModelType) async -> Result<URL, PoseModelError> {
    switch await fetchModel(auth: auth, type: type) {
    case .failure(let err):
      return .failure(err)
    case .success(let url):
      return .success(url)
    }
  }
  
  private func getOnDeviceModels(auth: APIAuth) async throws -> [ModelMetadata] {
    if let override = getOnDeviceModelOverride() {
      return [override]
    }

    var request = URLRequest(url: URL(string: "https://api.getguru.fitness/mlmodels/ondevice?sdkVersion=2.0.0")!)
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
