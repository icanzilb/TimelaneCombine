// swift-tools-version:5.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "TimelaneCombine",
    platforms: [
      .macOS(.v10_15),
      .iOS(.v13),
      .tvOS(.v13),
      .watchOS(.v6),
    ],
    products: [
        .library(
            name: "TimelaneCombine",
            targets: ["TimelaneCombine"]),
    ],
    dependencies: [
        .package(url: "https://github.com/icanzilb/TimelaneCore", from: "2.0.0")
    ],
    targets: [
        .target(
            name: "TimelaneCombine",
            dependencies: ["TimelaneCore"]),
        .testTarget(
            name: "TimelaneCombineTests",
            dependencies: ["TimelaneCombine", "TimelaneCoreTestUtils"]),
    ],
    swiftLanguageVersions: [.v5]
)
