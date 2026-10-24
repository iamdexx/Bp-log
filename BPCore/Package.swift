// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "BPCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "BPCore", targets: ["BPCore"])],
    targets: [
        .target(name: "BPCore"),
        .testTarget(name: "BPCoreTests", dependencies: ["BPCore"]),
    ]
)
