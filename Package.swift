// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "VKounters",
    platforms: [
        .macOS(.v26)
    ],
    dependencies: [
        .package(url: "https://github.com/swift-server/swift-aws-lambda-runtime.git", from: "2.0.0"),
        .package(url: "https://github.com/swift-server/swift-aws-lambda-events.git", from: "1.2.1"),
        .package(url: "https://github.com/swift-cloud/swift-cloud.git", from: "0.40.0"),
        .package(url: "https://github.com/valkey-io/valkey-swift.git", from: "0.3.0")
    ],
    targets: [
        .executableTarget(
            name: "VKounters",
            dependencies: [
                .product(name: "AWSLambdaRuntime", package: "swift-aws-lambda-runtime"),
                .product(name: "AWSLambdaEvents", package: "swift-aws-lambda-events"),
                .product(name: "Valkey", package: "valkey-swift"),
                .product(name: "CloudSDK", package: "swift-cloud")
            ]
        ),
        .executableTarget(
            name: "Infra",
            dependencies: [
                .product(name: "Cloud", package: "swift-cloud")
            ]
        ),
    ]
)
