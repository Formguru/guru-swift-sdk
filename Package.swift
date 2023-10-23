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
            targets: ["GuruSwiftSDK"]),
    ],
    dependencies: [
      .package(url: "https://github.com/WeTransfer/Mocker.git", from: "2.5.6"),
    ],
    targets: [
        .target(
            name: "GuruSwiftSDK",
            dependencies: ["C"],
            resources: [
              .copy("Resources/javascript.bundle"),
            ]
        ),
        .target(
          name: "C",
          dependencies: ["GuruEngine", "opencv2", "quickjs", "onnxruntime"],
          path: "Sources/C",
          linkerSettings: [LinkerSetting.linkedLibrary("c++")]
        ),
        .binaryTarget(
          name: "GuruEngine",
          // path: "../guruengine/GuruEngine.xcframework"
          url: "https://guru-dist.s3.us-west-2.amazonaws.com/xcframework/guru-engine/20231022/guru-engine.xcframework.zip",
          checksum: "ad1f18d11e7ad4fb0b038b5847cd32067cebb078ed0a37c2df267ea266e00079"
        ),
        .binaryTarget(
          name: "quickjs",
          url: "https://guru-dist.s3.us-west-2.amazonaws.com/xcframework/quickjs/20230905/quickjs.xcframework.zip",
          checksum: "b2695691fd981568520efbda1da0abad79ee493b589589c70070d005d178e15c"
        ),
        .binaryTarget(
          name: "onnxruntime",
          url: "https://guru-dist.s3.us-west-2.amazonaws.com/xcframework/onnxruntime/20230905/onnxruntime.xcframework.zip",
          checksum: "2a2a86285f1ebabca0aac22b4077e8ebbcfad4c3d8cc672921457e8e7ef17752"
        ),
        .binaryTarget(
          name: "opencv2",
          url: "https://guru-dist.s3.us-west-2.amazonaws.com/xcframework/opencv2/20230905/opencv2.xcframework.zip",
          checksum: "5169f71a867474027f5c399188c164055d5bcb728f9ec6db3f8969ee7d10879d"
        ),
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
