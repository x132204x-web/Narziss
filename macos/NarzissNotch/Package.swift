// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "NarzissNotch",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "NarzissNotch", targets: ["NarzissNotch"])],
    targets: [
        .target(name: "NotchCore"),
        .executableTarget(name: "NarzissNotch", dependencies: ["NotchCore"],
                          linkerSettings: [.linkedFramework("EventKit")]),
        .testTarget(name: "NotchCoreTests", dependencies: ["NotchCore", "NarzissNotch"])
    ],
    swiftLanguageModes: [.v5]
)
