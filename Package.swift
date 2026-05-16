// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "CozyTime",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .library(name: "CozyCore", targets: ["CozyCore"]),
        .executable(name: "CozyTime", targets: ["CozyTime"]),
        .executable(name: "CozyCoreSelfTest", targets: ["CozyCoreSelfTest"])
    ],
    dependencies: [
        .package(url: "https://github.com/airbnb/lottie-spm.git", from: "4.6.0")
    ],
    targets: [
        .target(name: "CozyCore"),
        .executableTarget(
            name: "CozyTime",
            dependencies: [
                "CozyCore",
                .product(name: "Lottie", package: "lottie-spm")
            ],
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
