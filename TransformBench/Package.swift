// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TransformBench",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "TransformBench",
            targets: ["TransformBench"]
        )
    ],
    dependencies: [
        // Add any external dependencies here if needed
    ],
    targets: [
        .executableTarget(
            name: "TransformBench",
            dependencies: [],
            path: "Sources/TransformBench",
            linkerSettings: [
                .linkedFramework("Accelerate")
            ]
        )
    ]
)
