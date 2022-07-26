/* Copyright (C) Guru Movement Labs Inc - All Rights Reserved
 * Unauthorized copying of this file, via any medium, is strictly prohibited.
 * Proprietary and confidential.
 */

public enum Activity : String {
  case shoulder_flexion
  
  func getDomain() -> String {
    return "mobility"
  }
}
