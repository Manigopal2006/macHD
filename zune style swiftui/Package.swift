// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ZuneExplorer",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "ZuneExplorer", targets: ["ZuneExplorer"])],
    targets: [.executableTarget(name: "ZuneExplorer", path: "Sources")]
)
