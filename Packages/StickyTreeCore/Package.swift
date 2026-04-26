// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "StickyTreeCore",
    platforms: [
        .iOS(.v14),
        .macOS(.v11)
    ],
    products: [
        .library(name: "StickyTreeCore", targets: ["StickyTreeCore"])
    ],
    targets: [
        .target(name: "StickyTreeCore"),
        .testTarget(name: "StickyTreeCoreTests", dependencies: ["StickyTreeCore"])
    ]
)
