// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Secretariat",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "Secretariat", targets: ["Secretariat"])],
    targets: [
        .target(name: "SecretariatCore"),
        .executableTarget(name: "Secretariat", dependencies: ["SecretariatCore"],
                          swiftSettings: [.defaultIsolation(MainActor.self)]),
        .testTarget(name: "SecretariatCoreTests", dependencies: ["SecretariatCore"])
    ]
)
