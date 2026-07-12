// swift-tools-version: 6.0
//
// DiffView - a standalone line-diff viewer component (SwiftUI / Foundation only, no other
// dependencies). Renders a unified diff of two texts as hunks with old / new line-number
// gutters and +/- markers, with context collapsing and size / render caps. Extracted from
// the ActionUI ActionUIDiff add-on, which now wraps this package as its `Diff` element -
// the same relationship RichText has to the ActionUIRichText add-on.

import PackageDescription

let package = Package(
    name: "DiffView",
    platforms: [
        .macOS("14.6"),
        .iOS("17.6"),
        .visionOS("2.6"),
    ],
    products: [
        .library(name: "DiffView", targets: ["DiffView"]),
    ],
    targets: [
        .target(name: "DiffView"),
        .testTarget(name: "DiffViewTests", dependencies: ["DiffView"]),
    ]
)
