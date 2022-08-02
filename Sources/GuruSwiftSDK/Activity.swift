/* Copyright (C) Guru Movement Labs Inc - All Rights Reserved
 * Unauthorized copying of this file, via any medium, is strictly prohibited.
 * Proprietary and confidential.
 */

public enum Activity : String {
  
  case bench_press
  case bodyweight_squat
  case burpee
  case chin_up
  case clean_and_jerk
  case deadlift
  case downward_dog
  case knee_to_chest
  case lunge
  case punch
  case push_up
  case shoulder_flexion
  case sit_up
  case snatch
  case sprint
  case squat
  
  func getDomain() -> String {
    switch self {
    case .bodyweight_squat, .burpee, .chin_up, .lunge, .push_up, .sit_up:
      return "calisthenics"
    case .knee_to_chest, .shoulder_flexion:
      return "mobility"
    case .bench_press, .clean_and_jerk, .deadlift, .snatch, .squat:
      return "weightlifting"
    case .downward_dog:
      return "yoga"
    case .punch:
      return "martial_arts"
    case .sprint:
      return "running"
    }
  }
}
