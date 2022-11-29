/* Copyright (C) Guru Movement Labs Inc - All Rights Reserved
 * Unauthorized copying of this file, via any medium, is strictly prohibited.
 * Proprietary and confidential.
 */

#if !os(macOS)
import Foundation
import AVFoundation
import UIKit
import MobileCoreServices
import CoreML
import Vision

public class LocalVideoInference : NSObject {
  let callback: InferenceConsumer
  let source: String
  let apiKey: String
  let maxDuration: TimeInterval
  let analysisPerSecond: Int
  let recordTo: URL?
  
  let session = AVCaptureSession()
  let inferenceLock = NSLock()
  let modelStore = ModelStore()
  var frameIndex = -1
  var poseModel: MLModel?
  let width = 480.0
  let height = 640.0
  
  var latestInference: FrameInference?
  var analysisClient: AnalysisClient?
  var videoId: String?
  var startedAt: Date?
  
  public init(consumer: InferenceConsumer,
              cameraPosition: AVCaptureDevice.Position,
              source: String,
              apiKey: String,
              maxDuration: TimeInterval = 60,
              analysisPerSecond: Int = 8,
              recordTo: URL? = nil,
              isPreviewEnabled: Bool = false) throws {
    callback = consumer
    self.source = source
    self.apiKey = apiKey
    self.maxDuration = maxDuration
    self.analysisPerSecond = analysisPerSecond
    self.recordTo = recordTo
    
    super.init()
    
    session.sessionPreset = .vga640x480
    let device =  AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: cameraPosition)
    if (device != nil) {
      device?.set(frameRate: 30)
      
      let input = try! AVCaptureDeviceInput(device: device!)
      session.addInput(input)
      
      let output = AVCaptureVideoDataOutput()
      output.alwaysDiscardsLateVideoFrames = false
      output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as AnyHashable as! String: kCVPixelFormatType_32BGRA]
      output.setSampleBufferDelegate(self, queue: DispatchQueue.main)
      session.addOutput(output)
      if (isPreviewEnabled) {
        Task {
          try! await self.startPreview()
        }
      }
    }
    else {
      throw InferenceSetupFailed.cameraNotFound(position: cameraPosition)
    }
  }
  
  private func startPreview() async throws {
    if #available(iOS 15, *) {
      try! await ensureModelIsReady();
      self.session.startRunning()
    }
    else {
      throw InferenceSetupFailed.iosRequirementUnmet
    }
  }
  
  public func start(activity: Activity) async throws -> String {
    if #available(iOS 15, *) {
      try! await ensureModelIsReady();
      
      videoId = try await createVideo(activity: activity)
      
      startedAt = Date()
      analysisClient = AnalysisClient(videoId: videoId!, apiKey: apiKey, maxPerSecond: analysisPerSecond)
      DispatchQueue.global(qos: .userInitiated).async {
        var recordOutput: AVCaptureMovieFileOutput? = nil
        if (self.recordTo != nil) {
          recordOutput = AVCaptureMovieFileOutput()
          self.session.addOutput(recordOutput!)
        }

        if (!self.session.isRunning) {
          self.session.startRunning()
        }
        
        recordOutput?.startRecording(to: self.recordTo!, recordingDelegate: self)
      }
      
      return videoId!
    }
    else {
      throw InferenceSetupFailed.iosRequirementUnmet
    }
  }
  
  public func stop() async throws -> Analysis {
    if (session.isRunning) {
      DispatchQueue.global(qos: .userInitiated).async {
        self.session.stopRunning()
      }
    }
    
    analysisClient!.waitUntilQuiet()
    return try await analysisClient!.flush()!
  }

  public func uploadVideo() async throws -> UploadResult {
    if (self.recordTo == nil) {
      throw UploadFailed.notRecorded()
    }
    if (session.isRunning) {
      throw UploadFailed.stillRecording()
    }

    let guruApiClient = GuruAPIClient(auth: APIKeyAuth(apiKey: apiKey))
    try await guruApiClient.uploadVideo(videoFile: recordTo!, videoId: videoId!)

    var uploadResult: UploadResult?
    while (uploadResult == nil) {
      let overlays = try await guruApiClient.overlays(videoId: videoId!)
      if (overlays == nil) {
        try await Task.sleep(nanoseconds: UInt64(Double(NSEC_PER_SEC)))
      }
      else {
        uploadResult = UploadResult(overlays: overlays!)
      }
    }
    
    return uploadResult!
  }
  
  @available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
  private func ensureModelIsReady() async throws {
    self.poseModel = try! await self.modelStore.getModel().get()
  }
  
  private func createVideo(activity: Activity) async throws -> String {
    var request = URLRequest(url: URL(string: "https://api.getguru.fitness/videos")!)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
    request.httpBody = try! JSONSerialization.data(withJSONObject: [
      "source": source,
      "domain": activity.getDomain(),
      "activity": activity.rawValue,
      "inference": "local",
      "resolutionWidth": width,
      "resolutionHeight": height
    ])
    
    let (data, response) = try! await URLSession.shared.data(for: request)
    
    if ((response as? HTTPURLResponse)!.statusCode == 200) {
      let json = try! JSONSerialization.jsonObject(with: data) as! [String: Any]
      return json["id"]! as! String
    }
    else {
      throw APICallFailed.createVideoFailed(error: String(decoding: data, as: UTF8.self))
    }
  }
  
  private func updateInference(image: UIImage, frameIndex: Int) -> FrameInference? {
    let frameTimestamp = Date()
    
    if (!inferenceLock.try()) {
      return nil
    }
    defer { inferenceLock.unlock() }
    
    let bbox: CGRect = estimateBoundingBox(prevFramePose: latestInference)
    
    do {
      let keypoints = try runInference(image: image, box: bbox)
      let secondsSinceStart = startedAt == nil ? 0 : Date().timeIntervalSinceReferenceDate - startedAt!.timeIntervalSinceReferenceDate

      latestInference = FrameInference(
        keypoints: keypoints,
        timestamp: frameTimestamp,
        secondsSinceStart: secondsSinceStart,
        frameIndex: frameIndex,
        previousFrame: latestInference
      )
      
      return latestInference
    }
    catch {
      print("Failed to run inference: \(error.localizedDescription)")
      return nil
    }
  }
  
  private func bufferToImage(imageBuffer: CMSampleBuffer) -> UIImage? {
    guard let pixelBuffer: CVImageBuffer = CMSampleBufferGetImageBuffer(imageBuffer) else {
      return nil
    }
    CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
    let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer)
    let width = CVPixelBufferGetWidth(pixelBuffer)
    let height = CVPixelBufferGetHeight(pixelBuffer)
    let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
    let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)
    guard let context = CGContext(data: baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: bytesPerRow, space: colorSpace, bitmapInfo: bitmapInfo.rawValue) else {
      return nil
    }
    guard let cgImage = context.makeImage() else {
      return nil
    }
    let image = UIImage(cgImage: cgImage, scale: 1, orientation: .up)
    CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)
    
    return rotateImage(image: image, radians: .pi/2)
  }
  
  private func estimateBoundingBox(prevFramePose: FrameInference?) -> CGRect {
    let defaultBbox = CGRect(x: 0, y: 0, width: 1.0, height: 1.0)
    if (prevFramePose == nil) {
      return defaultBbox;
    }
    
    func point(landmark: InferenceLandmark) -> Keypoint? {
      return prevFramePose!.keypointForLandmark(landmark)
    }
    func isVisible(point: Keypoint?) -> Bool {
      let minScore = 0.1
      return point != nil && point!.score > minScore
    }
    func getIfVisible(landmark: InferenceLandmark) -> Keypoint? {
      let point = point(landmark: landmark)
      return isVisible(point: point) ? point : nil
    }
    
    func getEnclosingBox(landmarks: [InferenceLandmark]) -> CGRect {
      var xMin = Double.greatestFiniteMagnitude, xMax = Double.leastNormalMagnitude
      var yMin = Double.greatestFiniteMagnitude, yMax = Double.leastNormalMagnitude
      
      for landmark in landmarks {
        let kpt = getIfVisible(landmark: landmark)
        if (kpt != nil) {
          xMin = min(xMin, kpt!.x)
          xMax = max(xMax, kpt!.x)
          yMin = min(yMin, kpt!.y)
          yMax = max(yMax, kpt!.y)
        }
      }
      return CGRect(
        x: xMin,
        y: yMin,
        width: xMax - xMin,
        height: yMax - yMin
      )
    }
    
    let leftShoulder = point(landmark: InferenceLandmark.leftShoulder)
    let rightShoulder = point(landmark: InferenceLandmark.rightShoulder)
    let leftHip = point(landmark: InferenceLandmark.leftHip)
    let rightHip = point(landmark: InferenceLandmark.rightHip)
    
    let isTorsoVisible = isVisible(point: leftShoulder) &&
    isVisible(point: leftHip) &&
    isVisible(point: rightShoulder) &&
    isVisible(point: rightHip)
    
    if (isTorsoVisible) {
      let center = CGPoint(x: (leftHip!.x + rightHip!.x) / 2, y: (leftHip!.y + rightHip!.y) / 2)
      let torsoBbox = getEnclosingBox(landmarks: [InferenceLandmark.leftShoulder, InferenceLandmark.rightShoulder, InferenceLandmark.leftHip, InferenceLandmark.rightHip])
      let bodyBbox = getEnclosingBox(landmarks: InferenceLandmark.allCases)
      
      let paddingFactor = 0.15
      let xPadding = paddingFactor * bodyBbox.width
      let yPadding = paddingFactor * bodyBbox.height
      let xMin = max(0, bodyBbox.minX - xPadding)
      let xMax = min(1.0, bodyBbox.minX + bodyBbox.width + xPadding)
      
      let yMin = max(0, bodyBbox.minY - yPadding)
      let yMax = min(1.0, bodyBbox.minY + bodyBbox.height + yPadding)
      
      let cropWidth = max(torsoBbox.width * 1.9, bodyBbox.width * 1.2)
      let cropHeight = max(torsoBbox.height * 1.9, bodyBbox.height * 1.2)
      let x1 = min(xMin, center.x - cropWidth / 2)
      let x2 = max(xMax, center.x + cropWidth / 2)
      let y1 = min(yMin, center.y - cropHeight / 2)
      let y2 = max(yMax, center.y + cropHeight / 2)
      
      return CGRect(x: x1, y: y1, width: x2 - x1, height: y2 - y1)
    } else {
      return defaultBbox;
    }
  }
  
  private func rotateImage(image: UIImage, radians: Float) -> UIImage {
    var newSize = CGRect(origin: CGPoint.zero, size: image.size).applying(CGAffineTransform(rotationAngle: CGFloat(radians))).size
    // Trim off the extremely small float value to prevent core graphics from rounding it up
    newSize.width = floor(newSize.width)
    newSize.height = floor(newSize.height)
    
    UIGraphicsBeginImageContextWithOptions(newSize, false, image.scale)
    let context = UIGraphicsGetCurrentContext()!
    
    // Move origin to middle
    context.translateBy(x: newSize.width / 2, y: newSize.height / 2)
    // Rotate around middle
    context.rotate(by: CGFloat(radians))
    // Draw the image at its center
    image.draw(in: CGRect(x: -image.size.width / 2, y: -image.size.height / 2, width: image.size.width, height: image.size.height))
    
    let newImage = UIGraphicsGetImageFromCurrentImageContext()
    UIGraphicsEndImageContext()
    
    return newImage!
  }
  
  private func runInference(image: UIImage, box: CGRect) throws -> [Int: Keypoint] {
    // our ML model only supports one resolution for now
    assert(image.size.height == height);
    assert(image.size.width == width);
    
    let bbox: [Int] = [
      Int((box.minX * width).rounded()),
      Int((box.minY * height).rounded()),
      Int((box.width * width).rounded()),
      Int((box.height * height).rounded()),
    ]
    
    var result = [Int: Keypoint]()
    if let rawKeypoints = inferPose(model: self.poseModel!, img: image.cgImage!, bbox: bbox) {
      for (key, values) in rawKeypoints {
        result[key] = Keypoint(
          x: Double(values[0]),
          y: Double(values[1]),
          score: Double(values[2])
        )
      }
    }
    return result;
  }
}

extension AVCaptureDevice {
  func set(frameRate: Double) {
    let ranges = activeFormat.videoSupportedFrameRateRanges
    var found = false
    for range in ranges {
      if (range.minFrameRate...range.maxFrameRate ~= frameRate) {
        found = true
      }
    }
    
    guard found else {
      print("Requested FPS is not supported by the device's activeFormat !")
      return
    }
    
    do {
      try lockForConfiguration()
      activeVideoMinFrameDuration = CMTimeMake(value: 1, timescale: Int32(frameRate))
      activeVideoMaxFrameDuration = CMTimeMake(value: 1, timescale: Int32(frameRate))
      unlockForConfiguration()
    }
    catch {
      print("LockForConfiguration failed with error: \(error.localizedDescription)")
    }
  }
}

extension LocalVideoInference: AVCaptureVideoDataOutputSampleBufferDelegate {
  public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
    let start = CFAbsoluteTimeGetCurrent()
    frameIndex += 1
    let thisFrameIndex = frameIndex
    
    let image: UIImage? = bufferToImage(imageBuffer: sampleBuffer)
    let buildInputDuration = 1000 * (CFAbsoluteTimeGetCurrent() - start)
    // TODO: debug log
    print("Build input: \(buildInputDuration) ms")

    if (image != nil) {
      
      DispatchQueue.global(qos: .userInteractive).async {
        let inference = self.updateInference(image: image!, frameIndex: thisFrameIndex)

        if (inference != nil) {
          Task {
            do {
              let analysis = try await self.analysisClient?.add(inference: inference!)

              if (analysis != nil) {
                DispatchQueue.main.async() {
                  self.callback.consumeAnalysis(analysis: analysis!)
                }
              }
            }
            catch {
              print("Failed to re-build analysis: \(error)")
            }
          }
        }
      }
      
      var inference = self.latestInference
      if (inference == nil) {
        let secondsSinceStart = startedAt == nil ? 0 : Date().timeIntervalSinceReferenceDate - startedAt!.timeIntervalSinceReferenceDate
        
        inference = FrameInference(
          keypoints: [:],
          timestamp: Date(),
          secondsSinceStart: secondsSinceStart,
          frameIndex: frameIndex,
          previousFrame: nil
        )
      }
      DispatchQueue.main.async {
        self.callback.consumeFrame(frame: image!, inference: inference!)
      }
      let durationMs = 1000 * (CFAbsoluteTimeGetCurrent() - start)
      print("Total \(durationMs) ms")

    }
      
    if (self.startedAt != nil && Date() > self.startedAt!.addingTimeInterval(self.maxDuration)) {
      Task {
        try await self.stop()
      }
    }
  }
}

extension LocalVideoInference: AVCaptureFileOutputRecordingDelegate {
  public func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
    print("Finished recording to \(outputFileURL) with error \(error)")
  }
}

#endif
