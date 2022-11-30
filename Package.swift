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
      .package(url: "https://github.com/weichsel/ZIPFoundation.git", .upToNextMinor(from: Version(0, 9, 15)))
      
    ],
    targets: [
        .target(
            name: "GuruSwiftSDK",
            dependencies: ["libgurucv", "ZIPFoundation"],
            resources: [
              .process("Resources")
            ]
        ),
        .target(name: "libgurucv", dependencies: ["opencv2"]),
        .binaryTarget(name: "opencv2", path: "thirdparty/opencv2.xcframework"),
        .testTarget(
            name: "GuruSwiftSDKTests",
            dependencies: ["GuruSwiftSDK", "Mocker"],
            resources: [
                .copy("Resources/rick-squat.mp4"),
                .copy("Resources/steph.jpg"),
                .copy("Resources/VipnasNoPreprocess.mlpackage.zip"),
            ]
        )
    ],
    // TODO: get rid of **/CMakeLists.txt?
    cxxLanguageStandard: .cxx11
)
