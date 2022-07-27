/* Copyright (C) Guru Movement Labs Inc - All Rights Reserved
 * Unauthorized copying of this file, via any medium, is strictly prohibited.
 * Proprietary and confidential.
 */

#if !os(macOS)
import UIKit

public protocol InferenceConsumer : AnyObject {
  func consumeFrame(frame: UIImage, inference: FrameInference?)
  
  func consumeAnalysis(analysis: Analysis)
}
#endif
