// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Secretariat",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "Secretariat", targets: ["Secretariat"])],
    dependencies: [.package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.9.6"),
                   .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", exact: "3.1.0")],
    targets: [
        .target(name: "SecretariatCore"),
        .executableTarget(name: "Secretariat", dependencies: ["SecretariatCore", .product(name: "Sparkle", package: "Sparkle"),
                                                                .product(name: "KeyboardShortcuts", package: "KeyboardShortcuts")],
                          swiftSettings: [.defaultIsolation(MainActor.self)],
                          // The app bundle carries Sparkle.framework in Contents/Frameworks (script/build.sh).
                          linkerSettings: [.unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"])]),
        .testTarget(name: "SecretariatCoreTests", dependencies: ["SecretariatCore"])
    ]
)
