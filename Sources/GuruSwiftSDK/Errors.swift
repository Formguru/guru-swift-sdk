/* Copyright (C) Guru Movement Labs Inc - All Rights Reserved
 * Unauthorized copying of this file, via any medium, is strictly prohibited.
 * Proprietary and confidential.
 */

import AVFoundation

public enum InferenceSetupFailed: Error {
  case cameraNotFound(position: AVCaptureDevice.Position)
  case iosRequirementUnmet
}

public enum APICallFailed: Error {
  case createVideoFailed(error: String)
  case getOverlaysFailed(error: String)
  case getOnDeviceModelsFailed(error: String)
  case uploadVideoFailed(error: String)
  case updateAnalysisFailed(error: String)
}

public enum UploadFailed: Error {
  case notRecorded(error: String = "This video was not recorded")
  case stillRecording(error: String = "Recording is still in progress")
}
