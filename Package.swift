// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "GuruSwiftSDK",
    platforms: [
        .iOS(.v13),
        .macOS(.v12)
    ],
    products: [
        .library(
            name: "GuruSwiftSDK",
            targets: ["GuruSwiftSDK", "libgurucv"]),
    ],
    dependencies: [
      .package(url: "https://github.com/WeTransfer/Mocker.git", from: "2.5.6"),
      .package(
        url: "https://github.com/weichsel/ZIPFoundation.git",
        .upToNextMinor(from: Version(0, 9, 15))
      )
    ],
    targets: [
        .target(
            name: "GuruSwiftSDK",
            dependencies: ["libgurucv", "ZIPFoundation", "C"],
            resources: [
              .process("Resources")
            ]
        ),
        .target(name: "libgurucv", dependencies: ["opencv2"]),
        .target(
          name: "C",
          dependencies: ["GuruEngine", "opencv2", "quickjs", "onnxruntime"],
          path: "Sources/C",
          linkerSettings: [LinkerSetting.linkedLibrary("c++")]
        ),
        .binaryTarget(name: "GuruEngine", path: "Modules/GuruEngine.xcframework"),
        .binaryTarget(name: "quickjs", path: "Modules/quickjs.xcframework"),
        .binaryTarget(name: "onnxruntime", path: "Modules/onnxruntime.xcframework"),
        .binaryTarget(name: "opencv2", path: "Modules/opencv2.xcframework"),
        .testTarget(
            name: "GuruSwiftSDKTests",
            dependencies: ["GuruSwiftSDK", "Mocker"],
            resources: [
                .copy("Resources/rick-squat.mp4"),
                .copy("Resources/steph.jpg")
            ]
        )
    ],
    cxxLanguageStandard: .cxx11
)
