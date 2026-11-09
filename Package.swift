// swift-tools-version: 5.9
import PackageDescription
let package = Package(
    name: "iPhoneRemote", platforms: [.macOS(.v14)],
    products: [.executable(name: "iPhoneRemote", targets: ["iPhoneRemote"])],
    targets: [
        .target(name: "RemoteCore"),
        .executableTarget(name: "iPhoneRemote", dependencies: ["RemoteCore"]),
        .testTarget(name: "RemoteCoreTests", dependencies: ["RemoteCore"])
    ]
)
