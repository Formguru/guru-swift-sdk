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
    ],
    targets: [
        .target(
            name: "GuruSwiftSDK",
            dependencies: [],
            resources: [
                .copy("VipnasEndToEnd.mlmodelc"),
            ]
        ),
        .testTarget(
            name: "GuruSwiftSDKTests",
            dependencies: ["GuruSwiftSDK"]),
    ]
)
