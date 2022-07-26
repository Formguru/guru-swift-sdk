/* Copyright (C) Guru Movement Labs Inc - All Rights Reserved
 * Unauthorized copying of this file, via any medium, is strictly prohibited.
 * Proprietary and confidential.
 */

import AVFoundation

public enum InferenceSetupFailed: Error {
  case cameraNotFound(position: AVCaptureDevice.Position)
}

public enum APICallFailed: Error {
  case createVideoFailed(error: String)
  case updateAnalysisFailed(error: String)
}
