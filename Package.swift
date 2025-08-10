// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "jenkins-mcp",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .executable(
            name: "jenkinscli",
            targets: ["JenkinsCLI"]
        ),
        .executable(
            name: "jenkins-mcp",
            targets: ["JenkinsMCP"]
        ),
        .library(
            name: "JenkinsSDK",
            targets: ["JenkinsSDK"]
        ),
        .library(
            name: "HTTPTransport",
            targets: ["HTTPTransport"]
        ),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        .package(url: "https://github.com/swift-server/async-http-client.git", from: "1.26.0"),
        .package(url: "https://github.com/apple/swift-http-types.git", from: "1.0.0"),
        //.package(url: "https://github.com/modelcontextprotocol/swift-sdk.git", from: "0.9.0"),
        .package(name: "swift-sdk", path: "../swift-mcp-sdk"),
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.6.1"),
        .package(url: "https://github.com/apple/swift-container-plugin.git", from: "1.0.2"),
        .package(url: "https://github.com/swift-server/swift-service-lifecycle.git", from: "2.8.0"),
        .package(url: "https://github.com/apple/swift-collections.git", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-system.git", from: "1.6.2"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "JenkinsSDK",
            dependencies: [
                "HTTPTransport",
                .product(name: "HTTPTypes", package: "swift-http-types"),
            ]
        ),
        .target(
            name: "HTTPTransport",
            dependencies: [
                .product(name: "AsyncHTTPClient", package: "async-http-client"),
                .product(name: "HTTPTypes", package: "swift-http-types"),
            ]
        ),
        .target(
            name: "Netrc"
        ),
        .executableTarget(
            name: "JenkinsCLI",
            dependencies: [
                "JenkinsSDK",
                "HTTPTransport",

            ]
        ),
        .executableTarget(
            name: "JenkinsMCP",
            dependencies: [
                "JenkinsSDK",
                "HTTPTransport",
                "Netrc",
                .product(name: "MCP", package: "swift-sdk"),
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "ServiceLifecycle", package: "swift-service-lifecycle"),
                .product(name: "DequeModule", package: "swift-collections"),
                .product(name: "SystemPackage", package: "swift-system"),
            ]
        ),
        .testTarget(
            name: "JenkinsSDKTests",
            dependencies: ["JenkinsSDK"]
        ),
        .testTarget(
            name: "JenkinsMCPTests",
            dependencies: ["JenkinsMCP"]
        ),
        .testTarget(
            name: "NetrcTests",
            dependencies: ["Netrc"]
        ),
    ]
)
