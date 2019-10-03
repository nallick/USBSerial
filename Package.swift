// swift-tools-version:5.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "USBSerial",
    products: [
        .library(
            name: "USBSerial",
            targets: ["USBSerial"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-log.git", from: "1.0.0"),
        .package(url: "https://github.com/yeokm1/SwiftSerial.git", from: "0.1.1"),
    ],
    targets: [
        .target(
            name: "USBSerial",
            dependencies: ["Logging", "SwiftSerial"],
            path: "Sources"
        ),
    ]
)
