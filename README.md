# DiffView

A standalone line-diff viewer component for SwiftUI (macOS / iOS / visionOS), and GTK 4 on Linux. Foundation and SwiftUI only (on Linux, FoundationEssentials and GTK), no other dependencies.

DiffView renders a unified diff of two texts: hunks with old / new line-number gutters, +/- markers, tinted added / removed rows, and "N unchanged lines" gaps where context collapsed. The diff is computed with the standard library's Myers algorithm (CollectionDifference). Degenerate inputs present honestly: identical texts say "No changes", oversized inputs fall back to a plain-text preview, and rendering caps at `maxRenderedLines` with an explicit truncation note.

## Platforms

macOS 14.6+, iOS 17.6+, visionOS 2.6+. Swift 6.

## Usage

```swift
import DiffView

DiffView(oldText: original, newText: revised)

// Or with explicit knobs (defaults shown):
DiffView(oldText: original, newText: revised, contextLines: 3, maxRenderedLines: 300)
```

## Linux

On Linux the same `DiffView` module builds over GTK 4 (`gtk4`, through pkg-config) and FoundationEssentials. The oldest versions supported are GNOME 48's: GTK 4.18 and GLib 2.84.

```swift
import DiffView

let diff = DiffGtkView(oldText: original, newText: revised)   // the same knobs and defaults
gtk_box_append(box, UnsafeMutablePointer<GtkWidget>(diff.widget))
diff.show(oldText: original, newText: revised2)                // the same inputs change nothing
```

- **`DiffGtkView`** draws what `DiffView` draws, from the same model and the same words: the line-number gutters, the +/- markers, the red and green tints, the "N unchanged lines" gaps and the notes. Its colors are the text color and libadwaita's palette red and green (GNOME's values without libadwaita), so they follow light and dark.
- **Text:** each number, marker and line is a label of its own, selectable with the pointer and never focused, as each `Text` of the SwiftUI view is. A long line wraps under its own column.
- **Size:** the widget takes the width it is offered, as the SwiftUI view does, and is as tall as its rows. Give a long diff a GtkScrolledWindow.
- The view keeps its widget alive as long as the object lives.

## ActionUI

ActionUI consumers get this component through the ActionUIDiff add-on, whose `Diff` element wraps this view for JSON documents. The chat component (ChatView) consumes DiffView directly for its tool-card diffs.
