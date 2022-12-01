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
            dependencies: ["libgurucv", "ZIPFoundation"],
            resources: [
              .process("Resources")
            ]
        ),
        .target(name: "libgurucv", dependencies: ["opencv2"]),
        
        // Note: this is built by thirdparty/build-xcframework.sh
        .binaryTarget(
          name: "opencv2",
          url: "https://formguru-datasets.s3.us-west-2.amazonaws.com/opencv2_ios_builds/opencv2.xcframework-b0dc474160e389b9c9045da5db49d03ae17c6a6b.zip",
          checksum: "ac7b21a7a3140713f30cf5800b4cabe098db49b367afa6e02edb85191e18870c"
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
