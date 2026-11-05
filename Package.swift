// swift-tools-version: 6.0
//
// DiffView - a standalone line-diff viewer component (SwiftUI / Foundation only on Apple, no other
// dependencies). Renders a unified diff of two texts as hunks with old / new line-number
// gutters and +/- markers, with context collapsing and size / render caps. Extracted from
// the ActionUI ActionUIDiff add-on, which now wraps this package as its `Diff` element -
// the same relationship RichText has to the ActionUIRichText add-on.
//
// On Linux the same DiffView module is built from the model and the text both views show (FoundationEssentials
// only) plus a GTK 4 view (Gtk/: DiffGtkView). The SwiftUI view is not compiled there.

import PackageDescription

#if os(Linux)
let package = Package(
    name: "DiffView",
    products: [
        .library(name: "DiffView", targets: ["DiffView"]),
    ],
    targets: [
        // GTK 4's C API, for the view.
        .systemLibrary(name: "CDiffViewGtk", pkgConfig: "gtk4"),
        .target(
            name: "DiffView",
            dependencies: ["CDiffViewGtk"],
            exclude: ["DiffView.swift"]   // the SwiftUI view
        ),
        .testTarget(name: "DiffViewTests", dependencies: ["DiffView", "CDiffViewGtk"]),
    ]
)
#else
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
        .target(name: "DiffView", exclude: ["Gtk"]),   // the Linux view
        .testTarget(name: "DiffViewTests", dependencies: ["DiffView"], exclude: ["Gtk"]),
    ]
)
#endif
