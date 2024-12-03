// swift-tools-version: 5.10

import PackageDescription
import CompilerPluginSupport

let package = Package(
    name: "SwiftSpellbookMacros",
    platforms: [.macOS(.v10_15), .iOS(.v13), .tvOS(.v13), .watchOS(.v6), .macCatalyst(.v13)],
    products: [
        .library(
            name: "SpellbookMacros",
            targets: ["SpellbookMacros"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-syntax.git", from: "600.0.1"),
    ],
    targets: [
        .macro(
            name: "_SpellbookMacros",
            dependencies: [
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
            ],
            path: "Sources/SpellbookMacrosImpl"
        ),
        .target(
            name: "SpellbookMacros",
            dependencies: ["_SpellbookMacros"]
        ),
        .testTarget(
            name: "SpellbookMacrosTests",
            dependencies: [
                "SpellbookMacros",
            ]
        ),
        .testTarget(
            name: "SpellbookMacrosImplTests",
            dependencies: [
                "_SpellbookMacros",
                .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
            ]
        ),
    ]
)
