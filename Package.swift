// swift-tools-version: 6.0
// SPDX-License-Identifier: MPL-2.0
import PackageDescription

let package = Package(
    name: "Timbr",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .library(name: "TimbreDesignSystem", targets: ["TimbreDesignSystem"]),
        .library(name: "TimbreCore", targets: ["TimbreCore"]),
        .library(name: "TimbreEngine", targets: ["TimbreEngine"]),
        .executable(name: "Timbr", targets: ["TimbreApp"]),
        .executable(name: "timbr-mute-keeper", targets: ["TimbrMuteKeeper"])
    ],
    targets: [
        .target(
            name: "CTimbreDSP",
            path: "Sources/CTimbreDSP",
            publicHeadersPath: "include",
            cxxSettings: [
                .headerSearchPath("include"),
                .unsafeFlags(["-std=c++20", "-O2"])
            ],
            linkerSettings: [
                .linkedFramework("Accelerate")
            ]
        ),
        .target(
            name: "TimbreDesignSystem",
            path: "design-system/generated",
            exclude: ["tokens.css"],
            sources: ["TimbreTokens.swift"]
        ),
        .target(
            name: "TimbreCore",
            dependencies: ["CTimbreDSP"],
            path: "Sources/TimbreCore",
            linkerSettings: [
                .linkedLibrary("sqlite3"),
                .linkedFramework("Network")
            ]
        ),
        .target(
            name: "TimbreEngine",
            dependencies: ["CTimbreDSP", "TimbreCore"],
            path: "Sources/TimbreEngine",
            linkerSettings: [
                .linkedFramework("CoreAudio"),
                .linkedFramework("AudioToolbox"),
                .linkedFramework("IOBluetooth"),
                .linkedFramework("CoreBluetooth"),
                .linkedFramework("AppKit")
            ]
        ),
        .executableTarget(
            name: "TimbrMuteKeeper",
            dependencies: ["TimbreCore"],
            path: "Sources/TimbrMuteKeeper",
            linkerSettings: [
                .linkedFramework("CoreAudio"),
                .linkedFramework("AudioToolbox")
            ]
        ),
        .executableTarget(
            name: "TimbreApp",
            dependencies: ["TimbreDesignSystem", "TimbreCore", "TimbreEngine"],
            path: "Sources/TimbreApp",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI"),
                .linkedFramework("Carbon")
            ]
        ),
        .testTarget(
            name: "TimbreDSPTests",
            dependencies: ["CTimbreDSP", "TimbreCore"],
            path: "Tests/CTimbreDSPTests"
        ),
        .testTarget(
            name: "TimbreCoreTests",
            dependencies: ["TimbreCore"],
            path: "Tests/TimbreCoreTests"
        ),
        .testTarget(
            name: "TimbreEngineTests",
            dependencies: ["TimbreEngine", "TimbreCore", "CTimbreDSP"],
            path: "Tests/TimbreEngineTests"
        ),
        .testTarget(
            name: "TimbreTokensTests",
            dependencies: ["TimbreDesignSystem"],
            path: "Tests/TimbreTokensTests"
        )
    ],
    cxxLanguageStandard: .cxx20
)
