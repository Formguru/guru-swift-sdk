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
      print(file)
      if file.hasSuffix(".mlmodelc") {
        let url = URL(string: file)!
        let modelId = file.prefix(file.count - url.pathExtension.count - 1)
        results.append(OnDeviceModel(modelId: String(modelId), localPath: root.appendingPathComponent(file)))
      }
    }
    return results
  }
  
  private func downloadFile(url: URL) async throws -> URL {
    let fm = FileManager.default
    let rootUrl = getModelStoreRoot()
    return try await withCheckedThrowingContinuation({ continuation in
      URLSession.shared.downloadTask(with: url, completionHandler: {
        urlOrNil, responseOrNil, errorOrNil in
        if let err = errorOrNil {
          continuation.resume(throwing: err)
        } else if let tmpUrl = urlOrNil {
          let outputUrl = rootUrl.appendingPathComponent(url.lastPathComponent)
          if FileManager.default.fileExists(atPath: outputUrl.path) {
            try! FileManager.default.removeItem(at: outputUrl)
          }
          try! FileManager.default.moveItem(at: tmpUrl, to: outputUrl)
          assert(FileManager.default.fileExists(atPath: outputUrl.path))
          continuation.resume(returning: outputUrl)
        } else {
          continuation.resume(throwing: PoseModelError.downloadFailed)
        }
      }).resume()
    })
  }
  
  private func fetchCurrentModelMetadata() -> Dictionary<String, String> {
    // TODO: call Guru to get this
    return [
      "modelId": "test-123",
      "modelUrl":  "https://formguru-datasets.s3.us-west-2.amazonaws.com/on-device/andrew-temp-test/VipnasNoPreprocess.mlpackage.zip"
    ]
  }
  
  private func fetchModel() async -> Result<URL, PoseModelError> {
    let modelMeta = fetchCurrentModelMetadata()
    let modelId = modelMeta["modelId"]!
    
    let existingModels = listModels()
    let targetModel = existingModels.first(where: {model in
      model.modelId == modelId
    })
    if targetModel != nil {
      return .success(targetModel!.localPath)
    }
    
    // model isn't available locally, we need to fetch and compile it
    let remoteUrl = URL(string: modelMeta["modelUrl"]!)!
    let fm = FileManager.default
    let modelZip: URL
    do {
      modelZip = try await downloadFile(url: remoteUrl)
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
      "\(modelId).\(modelUrl.pathExtension)")
    _ = try! fm.replaceItemAt(permanentUrl, withItemAt: modelUrl)
    print("Model compiled to \(permanentUrl)")
    return .success(permanentUrl)
  }
  
  public func getModel() async -> Result<MLModel, PoseModelError> {
    if (self.model == nil) {
      let result = await doInitModel()
      switch result {
      case .success(let model):
        self.model = model
      case .failure(let err):
        return .failure(err)
      }
    }
    return .success(self.model!)
  }
  
  private func doInitModel() async -> Result<MLModel, PoseModelError> {
    switch await fetchModel() {
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
