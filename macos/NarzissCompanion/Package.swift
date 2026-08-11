// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "NarzissCompanion",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "NarzissCompanion", targets: ["NarzissCompanion"])
    ],
    targets: [
        .target(
            name: "NarzissCompanionCore",
            path: "Sources/NarzissCompanionCore",
            linkerSettings: [.linkedFramework("AVFoundation")]
        ),
        .executableTarget(
            name: "NarzissCompanion",
            dependencies: ["NarzissCompanionCore"],
            path: "Sources/NarzissCompanion",
            linkerSettings: [
                .linkedFramework("ApplicationServices"),
                .linkedFramework("AVFoundation"),
                .linkedFramework("Speech")
            ]
        ),
        .testTarget(
            name: "NarzissCompanionCoreTests",
            dependencies: ["NarzissCompanionCore"],
            path: "Tests/NarzissCompanionCoreTests"
        )
    ],
    swiftLanguageModes: [.v5]
)
