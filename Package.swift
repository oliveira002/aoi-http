// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "Aoi",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "Aoi", path: "Sources"),
        .testTarget(name: "AoiTests", dependencies: ["Aoi"], path: "Tests"),
    ]
)
