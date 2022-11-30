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

actor ModelStore {
  
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
    let models = try! await GuruAPIClient(auth: auth).getOnDeviceModels()
    return models.first(where: { $0.modelType == .pose })!
  }
  
  private func fetchModel(auth: APIAuth) async -> Result<URL, PoseModelError> {
    guard let modelMeta = try? await fetchCurrentModelMetadata(auth: auth) else {
      return .failure(PoseModelError.downloadFailed)
    }
    
    let existingModels = listModels()
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
}
