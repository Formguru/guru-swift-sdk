//
//  File.swift
//  
//
//  Created by Adam Harwood on 28/7/2022.
//

import Foundation
@testable import GuruSwiftSDK

class TestUtils {
  
  static func randomDouble(max: Double = 1000.0) -> Double {
    return Double.random(in: 0.0 ..< max)
  }
  
  static func randomInteger(max: Int = 1000) -> Int {
    return Int.random(in: 0 ..< max)
  }
  
  static func randomString(length: Int = 16) -> String {
    let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    return String((0..<length).map{ _ in letters.randomElement()! })
  }
  
  static func randomKeypoint() -> Keypoint {
    return Keypoint(x: randomDouble(), y: randomDouble(), score: randomDouble())
  }
}
