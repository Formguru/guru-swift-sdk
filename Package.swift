// swift-tools-version: 5.6
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "GuruSwiftSDK",
    platforms: [
        .iOS(.v15),
        .macOS(.v12)
    ],
    products: [
        .library(
            name: "GuruSwiftSDK",
            targets: ["GuruSwiftSDK"]),
    ],
    dependencies: [
      .package(url: "https://github.com/WeTransfer/Mocker.git", from: "2.5.6")
    ],
    targets: [
        .target(
            name: "GuruSwiftSDK",
            dependencies: []
        ),
        .testTarget(
            name: "GuruSwiftSDKTests",
            dependencies: ["GuruSwiftSDK", "Mocker"]),
    ]
)
