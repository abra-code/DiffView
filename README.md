# DiffView

A standalone line-diff viewer component for SwiftUI (macOS / iOS / visionOS). Foundation and SwiftUI only, no other dependencies.

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

## ActionUI

ActionUI consumers get this component through the ActionUIDiff add-on, whose `Diff` element wraps this view for JSON documents. The chat component (ChatView) consumes DiffView directly for its tool-card diffs.
