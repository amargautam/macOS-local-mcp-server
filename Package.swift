// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "macos-local-mcp",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "macos-local-mcp", targets: ["MacOSLocalMCP"]),
        .executable(name: "MacOSLocalMCPAdmin", targets: ["MacOSLocalMCPAdmin"]),
    ],
    targets: [
        .executableTarget(
            name: "MacOSLocalMCP",
            path: "Sources/MacOSLocalMCP"
        ),
        .executableTarget(
            name: "MacOSLocalMCPAdmin",
            path: "Sources/MacOSLocalMCPAdmin",
            swiftSettings: [
                .unsafeFlags(["-parse-as-library"])
            ]
        ),
        .testTarget(
            name: "MacOSLocalMCPTests",
            dependencies: ["MacOSLocalMCP"],
            path: "Tests/MacOSLocalMCPTests"
        ),
        .testTarget(
            name: "MacOSLocalMCPAdminTests",
            dependencies: ["MacOSLocalMCPAdmin"],
            path: "Tests/MacOSLocalMCPAdminTests"
        ),
    ]
)
