// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "Bridget",
  platforms: [
    .iOS(.v17),
    .macOS(.v14),
  ],
  products: [
    .library(
      name: "Bridget",
      targets: ["Bridget"]
    )
  ],
  dependencies: [
    // Swift Testing framework
    .package(url: "https://github.com/apple/swift-testing", from: "0.6.0"),

    // Existing development dependencies
    .package(url: "https://github.com/realm/SwiftLint.git", from: "0.50.0"),
    .package(url: "https://github.com/nicklockwood/SwiftFormat.git", from: "0.51.0"),
  ],
  targets: [
    // Main Bridget library target
    .target(
      name: "Bridget",
      dependencies: [],
      path: "Bridget",
      exclude: [
        "BridgetApp.swift",
        "Info.plist",
        "Bridget.entitlements",
        "seattle_drawbridges.topology.json",
        "Examples",
        "Views",
        "ViewModels",
        "Documentation",
      ],
      sources: ["Services", "Models", "Extensions"],
      resources: [
        .process("Assets.xcassets")
      ]
    ),

    // BridgetTests target using Swift Testing
    .testTarget(
      name: "BridgetTests",
      dependencies: [
        "Bridget",
        .product(name: "Testing", package: "swift-testing"),
      ],
      path: "BridgetTests",
      resources: [
        .process("TestResources")
      ]
    ),
  ]
)
