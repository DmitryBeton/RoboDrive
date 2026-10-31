// swift-tools-version: 6.2
import PackageDescription
let package = Package(
    name: "RoboDriveCore",
    products: [.library(name: "RoboDriveCore", targets: ["RoboDriveCore"])],
    targets: [
        .target(name: "RoboDriveCore", path: "RoboDrive/Core", resources: [.process("Resources")]),
        .testTarget(name: "RoboDriveCoreTests", dependencies: ["RoboDriveCore"], path: "Tests/RoboDriveCoreTests")
    ]
)
