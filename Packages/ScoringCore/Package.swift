// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ScoringCore",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "ScoringCore", targets: ["ScoringCore"]),
    ],
    targets: [
        .target(name: "ScoringCore"),
        .testTarget(name: "ScoringCoreTests", dependencies: ["ScoringCore"]),
    ]
)
