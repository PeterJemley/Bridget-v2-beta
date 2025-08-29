// swift-tools-version: 5.9
import PackageDescription

let package = Package(
  name: "BridgetTools",
  platforms: [
    .macOS(.v13)
  ],
  dependencies: [
    .package(url: "https://github.com/realm/SwiftLint.git", from: "0.50.0"),
    .package(url: "https://github.com/nicklockwood/SwiftFormat.git", from: "0.51.0"),
  ],
  targets: [
    .target(
      name: "BridgetTools",
      dependencies: [])
  ])
