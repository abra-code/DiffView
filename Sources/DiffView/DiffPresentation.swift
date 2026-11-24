// Sources/DiffView/DiffPresentation.swift
//
// What both views show beside the lines themselves - the notes, the "N unchanged lines" gaps, the +/- markers -
// and how much of a long diff they render, so the SwiftUI view (DiffView.swift), the GTK view
// (Gtk/DiffGtkView.swift) and a view outside this package (ActionUI's Diff element on Windows, drawn with WinUI)
// read the same. Portable: no UI framework.

public enum DiffPresentation {
    /// Shown above the plain-text fallback when the inputs are too large to diff.
    public static let tooLargeNote = "Diff too large to render; showing the new text"

    /// Shown alone when the two texts have the same lines.
    public static let identicalNote = "No changes"

    // The counts come written as each view's locale writes them ("1,234" in English): the SwiftUI view passes
    // count.formatted(), as its Text once wrote an interpolated count, and the GTK view the C library's grouping.

    /// Shown after the last rendered line when `number` more diff lines (written as the view writes numbers) did not
    /// fit under the render cap.
    public static func truncatedNote(_ number: String) -> String {
        "\u{2026} truncated (\(number) more diff lines)"
    }

    /// Stands for `count` unchanged lines collapsed between hunks (or after the last one); `number` is `count` as
    /// the view writes it.
    public static func gap(_ count: Int, _ number: String) -> String {
        "\u{22EF} \(number) unchanged line\(count == 1 ? "" : "s")"
    }

    /// The new text shown when the inputs are too large to diff, cut at 4,000 characters.
    public static func fallbackText(_ newText: String) -> String {
        newText.count > 4000 ? newText.prefix(4000) + "\n\u{2026} (truncated)" : newText
    }

    /// The marker column of a line.
    public static func marker(_ kind: DiffLine.Kind) -> String {
        switch kind {
        case .context:
            return " "
        case .removed:
            return "-"
        case .added:
            return "+"
        }
    }

    /// How much of the result fits under `limit` rendered lines: every hunk before
    /// `hunkCount - 1` renders whole, the last one renders `linesInLastHunk`.
    public static func visibleLines(of result: DiffResult, limit: Int)
        -> (hunkCount: Int, linesInLastHunk: Int, truncatedLineCount: Int) {
        let limit = max(limit, 0)   // a negative cap renders nothing; prefix(-n) in the views would trap
        var total = 0
        for hunk in result.hunks {
            total += hunk.lines.count
        }
        guard total > limit else {
            return (result.hunks.count, result.hunks.last?.lines.count ?? 0, 0)
        }
        var remaining = limit
        for hunk in result.hunks {
            if hunk.lines.count >= remaining {
                return (hunk.id + 1, remaining, total - limit)
            }
            remaining -= hunk.lines.count
        }
        return (result.hunks.count, result.hunks.last?.lines.count ?? 0, 0)   // unreachable
    }
}
