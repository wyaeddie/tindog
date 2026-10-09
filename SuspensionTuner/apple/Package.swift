// swift-tools-version:5.9
import PackageDescription

// Library + tests only. The app itself is built from project.yml (xcodegen), which gives it
// a bundle ID and Info.plist. An SPM executable target has neither, so if one were listed here
// Xcode would offer it as a runnable scheme and it would crash on iPhone/iPad at launch
// ("BUNDLE_IDENTIFIER_FOR_CURRENT_PROCESS_IS_NIL").
let targets: [Target] = [
    .target(name: "SuspensionKit", resources: [.process("Resources")]),
    .testTarget(name: "SuspensionKitTests", dependencies: ["SuspensionKit"]),
]
let products: [Product] = [.library(name: "SuspensionKit", targets: ["SuspensionKit"])]

let package = Package(
    name: "SuspensionTuner",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: products,
    targets: targets
)
