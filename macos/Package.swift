// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "macos-vm-boot",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "macos-vm-boot",
            targets: ["macos-vm-boot"]
        )
    ],
    targets: [
        .executableTarget(
            name: "macos-vm-boot",
            path: "Sources/macos-vm-boot"
        )
    ]
)
