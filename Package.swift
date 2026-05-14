// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "CozyTime",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "CozyCore", targets: ["CozyCore"]),
        .executable(name: "CozyTime", targets: ["CozyTime"]),
        .executable(name: "CozyCoreSelfTest", targets: ["CozyCoreSelfTest"])
    ],
    targets: [
        .target(name: "CozyCore"),
        .executableTarget(
            name: "CozyTime",
            dependencies: ["CozyCore"],
            resources: [
                .process("Resources")
            ]
        ),
        .executableTarget(
            name: "CozyCoreSelfTest",
            dependencies: ["CozyCore"]
        ),
        .testTarget(
            name: "CozyCoreTests",
            dependencies: ["CozyCore"]
        )
    ]
)
