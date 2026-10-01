// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TexasWaterCore",
    platforms: [
        .iOS(.v17),
        .macOS(.v13)
    ],
    products: [
        .library(name: "TexasWaterCore", targets: ["TexasWaterCore"]),
        .executable(name: "reservoir-data-proof", targets: ["ReservoirDataProof"])
    ],
    targets: [
        .target(name: "TexasWaterCore"),
        .executableTarget(
            name: "ReservoirDataProof",
            dependencies: ["TexasWaterCore"]
        ),
        .testTarget(
            name: "TexasWaterCoreTests",
            dependencies: ["TexasWaterCore"],
            resources: [.copy("Fixtures")]
        )
    ]
)
