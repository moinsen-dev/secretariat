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
                          // SwiftPM records the deployment target (14.0) as the SDK version; macOS then shows the app in the
                          // old look for compatibility. Record the SDK it is built with so it gets the current design (Liquid Glass).
                          linkerSettings: [.unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks",
                                                         "-Xlinker", "-platform_version", "-Xlinker", "macos",
                                                         "-Xlinker", "14.0", "-Xlinker", "27.0"])]),
        .testTarget(name: "SecretariatCoreTests", dependencies: ["SecretariatCore"])
    ]
)
