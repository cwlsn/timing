// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "TimingCore",
    platforms: [.iOS("26.1"), .macOS(.v15)],
    products: [.library(name: "TimingCore", targets: ["TimingCore"])],
    targets: [
        .target(name: "TimingCore"),
        .testTarget(name: "TimingCoreTests", dependencies: ["TimingCore"]),
    ]
)
