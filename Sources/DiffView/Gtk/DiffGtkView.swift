// Sources/DiffView/Gtk/DiffGtkView.swift
//
// The Linux view: the same unified diff as the SwiftUI DiffView, as GTK widgets. A column of rows on a faint
// rounded background; each row the old and new line numbers, the +/- marker and the line, on a red tint for a
// removed line and a green one for an added line; "N unchanged lines" where context collapsed; and the same notes
// for identical texts, inputs too large to diff, and a diff cut at `maxRenderedLines`. The words come from
// DiffPresentation, as the SwiftUI view's do.
//
// Each piece of text is a label of its own, selectable with the pointer but never focused, as each Text of the
// SwiftUI view is selectable (.textSelection) and takes no keyboard focus. A long line wraps. The line's label
// expands horizontally, so the column does too: the SwiftUI view takes the width it is offered.
//
// A GTK program places `widget` in its widget tree; the view keeps the widget alive (one reference of its own) as
// long as the object lives.

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import CDiffViewGtk
import Glibc

@MainActor
public final class DiffGtkView {
    /// The column (a `GtkWidget *`).
    public let widget: OpaquePointer

    public private(set) var oldText: String
    public private(set) var newText: String
    public private(set) var contextLines: Int
    public private(set) var maxRenderedLines: Int

    private var column: UnsafeMutablePointer<GtkBox> {
        UnsafeMutableRawPointer(widget).assumingMemoryBound(to: GtkBox.self)
    }

    public init(oldText: String, newText: String, contextLines: Int = 3, maxRenderedLines: Int = 300) {
        self.oldText = oldText
        self.newText = newText
        self.contextLines = contextLines
        self.maxRenderedLines = maxRenderedLines
        let made = gtk_box_new(GTK_ORIENTATION_VERTICAL, 0)!
        g_object_ref_sink(UnsafeMutableRawPointer(made))
        widget = OpaquePointer(made)
        DiffGtkStyle.install()
        gtk_widget_add_css_class(made, DiffGtkStyle.column)
        rebuild()
    }

    /// Shows the diff of `oldText` and `newText`. The same texts and settings as shown change nothing.
    public func show(oldText: String, newText: String, contextLines: Int = 3, maxRenderedLines: Int = 300) {
        guard oldText != self.oldText || newText != self.newText || contextLines != self.contextLines
                || maxRenderedLines != self.maxRenderedLines else {
            return
        }
        self.oldText = oldText
        self.newText = newText
        self.contextLines = contextLines
        self.maxRenderedLines = maxRenderedLines
        rebuild()
    }

    isolated deinit {
        g_object_unref(UnsafeMutableRawPointer(widget))
    }

    // MARK: - Building

    private func rebuild() {
        while let child = gtk_widget_get_first_child(UnsafeMutablePointer<GtkWidget>(widget)) {
            gtk_box_remove(column, child)
        }
        let result = DiffComputer.compute(oldText: oldText, newText: newText, context: contextLines)
        if result.exceedsSizeLimit {
            append(note(DiffPresentation.tooLargeNote))
            append(fallback(DiffPresentation.fallbackText(newText)))
        } else if result.isIdentical {
            append(note(DiffPresentation.identicalNote))
        } else {
            appendHunks(result)
        }
    }

    private func appendHunks(_ result: DiffResult) {
        let visible = DiffPresentation.visibleLines(of: result, limit: maxRenderedLines)
        for hunk in result.hunks.prefix(visible.hunkCount) {
            if hunk.skippedBefore > 0 {
                append(gap(hunk.skippedBefore))
            }
            let isLastVisible = hunk.id == visible.hunkCount - 1
            for line in isLastVisible ? Array(hunk.lines.prefix(visible.linesInLastHunk)) : hunk.lines {
                append(row(line))
            }
        }
        if visible.truncatedLineCount > 0 {
            append(note(DiffPresentation.truncatedNote(Self.grouped(visible.truncatedLineCount))))
        } else if result.trailingSkippedLines > 0 {
            append(gap(result.trailingSkippedLines))
        }
    }

    private func append(_ child: UnsafeMutablePointer<GtkWidget>) {
        gtk_box_append(column, child)
    }

    // MARK: - Rows

    /// The numbers, the marker and the line, on the line's tint.
    private func row(_ line: DiffLine) -> UnsafeMutablePointer<GtkWidget> {
        let row = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 0)!
        gtk_widget_add_css_class(row, DiffGtkStyle.row)
        gtk_widget_add_css_class(row, "monospace")
        switch line.kind {
        case .context:
            break
        case .removed:
            gtk_widget_add_css_class(row, DiffGtkStyle.removed)
        case .added:
            gtk_widget_add_css_class(row, DiffGtkStyle.added)
        }
        let marker = label(DiffPresentation.marker(line.kind), secondary: true)
        gtk_widget_set_size_request(marker, 14, -1)
        gtk_label_set_xalign(opaque(marker), 0.5)
        // An empty line keeps one line's height, as the SwiftUI view's " " does.
        let text = label(line.text.isEmpty ? " " : line.text, secondary: false)
        gtk_label_set_wrap(opaque(text), 1)
        gtk_label_set_wrap_mode(opaque(text), PANGO_WRAP_WORD_CHAR)
        gtk_widget_set_hexpand(text, 1)
        let rowBox = UnsafeMutableRawPointer(row).assumingMemoryBound(to: GtkBox.self)
        for child in [number(line.oldNumber), number(line.newNumber), marker, text] {
            // At the top of a wrapped line, as the SwiftUI row's HStack(alignment: .top) places them.
            gtk_widget_set_valign(child, GTK_ALIGN_START)
            gtk_box_append(rowBox, child)
        }
        return row
    }

    /// A line number, right-aligned in a 34-pixel column with 4 pixels after it; nothing for the side a line is not on.
    private func number(_ value: Int?) -> UnsafeMutablePointer<GtkWidget> {
        let number = label(value.map(String.init) ?? "", secondary: true)
        gtk_widget_set_size_request(number, 34, -1)
        gtk_widget_set_margin_end(number, 4)
        gtk_label_set_xalign(opaque(number), 1)
        return number
    }

    /// "N unchanged lines", small and centered.
    private func gap(_ count: Int) -> UnsafeMutablePointer<GtkWidget> {
        let gap = label(DiffPresentation.gap(count, Self.grouped(count)), secondary: true)
        gtk_widget_add_css_class(gap, DiffGtkStyle.gap)
        gtk_label_set_xalign(opaque(gap), 0.5)
        return gap
    }

    /// A small note at the left.
    private func note(_ text: String) -> UnsafeMutablePointer<GtkWidget> {
        let note = label(text, secondary: true)
        gtk_widget_add_css_class(note, DiffGtkStyle.note)
        gtk_label_set_wrap(opaque(note), 1)
        gtk_label_set_wrap_mode(opaque(note), PANGO_WRAP_WORD_CHAR)
        return note
    }

    /// The new text as it is, for inputs too large to diff.
    private func fallback(_ text: String) -> UnsafeMutablePointer<GtkWidget> {
        let fallback = label(text, secondary: false)
        gtk_widget_add_css_class(fallback, DiffGtkStyle.fallback)
        gtk_widget_add_css_class(fallback, "monospace")
        gtk_label_set_wrap(opaque(fallback), 1)
        gtk_label_set_wrap_mode(opaque(fallback), PANGO_WRAP_WORD_CHAR)
        gtk_widget_set_hexpand(fallback, 1)
        return fallback
    }

    /// A selectable label that takes no focus, at the left; `secondary` in the secondary text color.
    private func label(_ text: String, secondary: Bool) -> UnsafeMutablePointer<GtkWidget> {
        let label = gtk_label_new(text)!
        gtk_label_set_xalign(opaque(label), 0)
        gtk_label_set_selectable(opaque(label), 1)
        // After set_selectable, which turns focus on: a focusable label would take the window's first focus and
        // select its whole text.
        gtk_widget_set_focusable(label, 0)
        if secondary {
            gtk_widget_add_css_class(label, DiffGtkStyle.secondary)
        }
        return label
    }

    /// `count` with the digit grouping of the C library's numeric locale ("1,234" in English, "1234" in the C locale),
    /// which GTK sets from the environment when it starts. FoundationEssentials has no locale formatting.
    static func grouped(_ count: Int) -> String {
        var buffer = [CChar](repeating: 0, count: 64)
        let written = withVaList([count]) { arguments in
            vsnprintf(&buffer, buffer.count, "%'ld", arguments)
        }
        guard written > 0, Int(written) < buffer.count else {
            return String(count)
        }
        return String(cString: buffer)
    }

    /// The label as GTK's label functions take it (GtkLabel is opaque to Swift).
    private func opaque(_ widget: UnsafeMutablePointer<GtkWidget>) -> OpaquePointer {
        OpaquePointer(widget)
    }
}

/// The view's style: its CSS classes and the one provider for the default display that draws them. The values are
/// the SwiftUI view's as ActionUI's GTK port draws SwiftUI styles: the caption font is libadwaita's caption size,
/// 82%, and caption2 70%; secondary text is the text color at 55%; Color.red and Color.green are libadwaita's
/// palette red and green, with GNOME's values for a program without libadwaita.
@MainActor
enum DiffGtkStyle {
    static let column = "diffview"
    static let row = "diffview-row"
    static let removed = "diffview-removed"
    static let added = "diffview-added"
    static let secondary = "diffview-secondary"
    static let gap = "diffview-gap"
    static let note = "diffview-note"
    static let fallback = "diffview-fallback"

    private static var installed = false

    static func install() {
        guard !installed, let display = gdk_display_get_default(), let provider = gtk_css_provider_new() else {
            return
        }
        installed = true
        gtk_css_provider_load_from_string(provider, """
            .\(column) { background-color: alpha(alpha(currentColor, 0.55), 0.05); border-radius: 6px; }
            .\(row) { font-family: monospace; font-size: 82%; padding: 1px 0; }
            .\(removed) { background-color: alpha(var(--red-3, #e01b24), 0.12); }
            .\(added) { background-color: alpha(var(--green-4, #2ec27e), 0.12); }
            .\(secondary) { color: alpha(currentColor, 0.55); }
            .\(gap) { font-size: 70%; padding: 2px 0; }
            .\(note) { font-size: 70%; padding: 4px; }
            .\(fallback) { font-family: monospace; font-size: 82%; padding: 6px; }
            """)
        gtk_style_context_add_provider_for_display(display, OpaquePointer(provider),
                                                   guint(GTK_STYLE_PROVIDER_PRIORITY_APPLICATION))
        g_object_unref(UnsafeMutableRawPointer(provider))
    }
}
