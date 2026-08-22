// swift-tools-version: 5.9
//
//  TouchBarSupport
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import PackageDescription

let package = Package(
    name: "TouchBarSupport",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(name: "TouchBarSupport", targets: ["TouchBarSupport"]),
    ],
    targets: [
        .target(name: "TouchBarSupport"),
    ],
)
