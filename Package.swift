// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "TymeHelper",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "TymeHelper"
        ),
    ]
)
