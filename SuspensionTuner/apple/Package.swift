// swift-tools-version:5.9
import PackageDescription

var targets: [Target] = [
    .target(name: "SuspensionKit", resources: [.process("Resources")]),
    .testTarget(name: "SuspensionKitTests", dependencies: ["SuspensionKit"]),
]
var products: [Product] = [.library(name: "SuspensionKit", targets: ["SuspensionKit"])]

#if os(macOS)
// `swift run SuspensionTunerApp` launches the macOS app straight from Terminal.
// For iOS + macOS bundles, generate the Xcode project from project.yml (see README).
targets.append(.executableTarget(name: "SuspensionTunerApp", dependencies: ["SuspensionKit"]))
products.append(.executable(name: "SuspensionTunerApp", targets: ["SuspensionTunerApp"]))
#endif

let package = Package(
    name: "SuspensionTuner",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: products,
    targets: targets
)
