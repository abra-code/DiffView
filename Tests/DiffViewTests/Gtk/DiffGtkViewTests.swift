// Tests/DiffViewTests/Gtk/DiffGtkViewTests.swift
//
// The GTK view: what rows it builds for a diff, the notes for the degenerate cases, the cut at maxRenderedLines,
// and that its labels can be selected but never take the focus. They need a display: in a box, run them in the
// GNOME session; without one they skip.

import CDiffViewGtk
import Glibc
import XCTest
@testable import DiffView

@MainActor
private var displayOpened: Bool?

/// Whether GTK has a display, asked once for the whole run: after a failed gtk_init_check, GTK aborts on the next one.
@MainActor
private func gtkDisplay() -> Bool {
    if let known = displayOpened {
        return known
    }
    let opened = gtk_init_check() != 0
    displayOpened = opened
    return opened
}

@MainActor
final class DiffGtkViewTests: XCTestCase {

    override func setUp() async throws {
        try XCTSkipUnless(gtkDisplay(), "needs a display")
    }

    /// The column's children.
    private func children(_ view: DiffGtkView) -> [UnsafeMutablePointer<GtkWidget>] {
        children(of: UnsafeMutablePointer<GtkWidget>(view.widget))
    }

    private func children(of widget: UnsafeMutablePointer<GtkWidget>) -> [UnsafeMutablePointer<GtkWidget>] {
        var result: [UnsafeMutablePointer<GtkWidget>] = []
        var child = gtk_widget_get_first_child(widget)
        while let current = child {
            result.append(current)
            child = gtk_widget_get_next_sibling(current)
        }
        return result
    }

    /// A label's text.
    private func text(_ widget: UnsafeMutablePointer<GtkWidget>) -> String {
        String(cString: gtk_label_get_text(OpaquePointer(widget)))
    }

    /// A row's four texts: old number, new number, marker, line.
    private func texts(ofRow row: UnsafeMutablePointer<GtkWidget>) -> [String] {
        children(of: row).map(text)
    }

    private func hasClass(_ widget: UnsafeMutablePointer<GtkWidget>, _ name: String) -> Bool {
        gtk_widget_has_css_class(widget, name) != 0
    }

    func testRowsShowNumbersMarkersAndLines() {
        let view = DiffGtkView(oldText: "keep\nold\n\nkeep2\n", newText: "keep\nnew\n\nkeep2\n")
        let rows = children(view)
        XCTAssertEqual(rows.count, 5)
        XCTAssertEqual(texts(ofRow: rows[0]), ["1", "1", " ", "keep"])
        XCTAssertEqual(texts(ofRow: rows[1]), ["2", "", "-", "old"])
        XCTAssertEqual(texts(ofRow: rows[2]), ["", "2", "+", "new"])
        XCTAssertEqual(texts(ofRow: rows[3]), ["3", "3", " ", " "], "an empty line keeps a line's height")
        XCTAssertTrue(hasClass(rows[1], DiffGtkStyle.removed))
        XCTAssertTrue(hasClass(rows[2], DiffGtkStyle.added))
        XCTAssertFalse(hasClass(rows[0], DiffGtkStyle.removed) || hasClass(rows[0], DiffGtkStyle.added))
        for row in rows {
            XCTAssertTrue(hasClass(row, DiffGtkStyle.row))
        }
    }

    func testCollapsedLinesBecomeGaps() {
        let filler = (1...20).map { "line \($0)" }.joined(separator: "\n")
        let view = DiffGtkView(oldText: "START\n" + filler + "\nEND\nTAIL1\nTAIL2\nTAIL3\nTAIL4\n",
                               newText: "CHANGED\n" + filler + "\nEND2\nTAIL1\nTAIL2\nTAIL3\nTAIL4\n",
                               contextLines: 2)
        let texts = children(view).map { hasClass($0, DiffGtkStyle.gap) ? text($0) : "row" }
        XCTAssertEqual(texts, ["row", "row", "row", "row", "\u{22EF} 16 unchanged lines",
                               "row", "row", "row", "row", "row", "row", "\u{22EF} 2 unchanged lines"])
    }

    func testIdenticalTextsSayNoChanges() {
        let view = DiffGtkView(oldText: "a\nb\n", newText: "a\nb")
        let rows = children(view)
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(text(rows[0]), "No changes")
        XCTAssertTrue(hasClass(rows[0], DiffGtkStyle.note))
    }

    func testTooLargeShowsTheNewText() {
        let big = (1...2001).map(String.init).joined(separator: "\n")
        let view = DiffGtkView(oldText: big, newText: big + "\nx")
        let rows = children(view)
        XCTAssertEqual(rows.count, 2)
        XCTAssertEqual(text(rows[0]), "Diff too large to render; showing the new text")
        XCTAssertTrue(hasClass(rows[1], DiffGtkStyle.fallback))
        XCTAssertEqual(text(rows[1]), DiffPresentation.fallbackText(big + "\nx"))
        XCTAssertTrue(text(rows[1]).hasSuffix("\n\u{2026} (truncated)"), "over 4,000 characters is cut")
    }

    func testCutAtMaxRenderedLines() {
        let view = DiffGtkView(oldText: "", newText: (1...10).map { "n\($0)" }.joined(separator: "\n"), maxRenderedLines: 4)
        let rows = children(view)
        XCTAssertEqual(rows.count, 5)
        XCTAssertEqual(texts(ofRow: rows[3]), ["", "4", "+", "n4"])
        XCTAssertEqual(text(rows[4]), "\u{2026} truncated (6 more diff lines)")
    }

    func testLabelsAreSelectableButNotFocusable() {
        let view = DiffGtkView(oldText: "a\n", newText: "b\n")
        let labels = children(view).flatMap { children(of: $0) }
        XCTAssertEqual(labels.count, 8)
        for widget in labels {
            XCTAssertNotEqual(gtk_label_get_selectable(OpaquePointer(widget)), 0)
            XCTAssertEqual(gtk_widget_get_focusable(widget), 0)
        }
    }

    func testTheLineExpandsAndWrapsUnderItsTopAlignedNumbers() {
        let view = DiffGtkView(oldText: "a\n", newText: "b\n")
        let line = children(of: children(view)[0])[3]
        XCTAssertNotEqual(gtk_widget_get_hexpand(line), 0)
        XCTAssertNotEqual(gtk_label_get_wrap(OpaquePointer(line)), 0)
        for child in children(of: children(view)[0]) {
            XCTAssertEqual(gtk_widget_get_valign(child), GTK_ALIGN_START, "a wrapped line's number and marker stay at its top")
        }
        XCTAssertNotEqual(gtk_widget_compute_expand(UnsafeMutablePointer<GtkWidget>(view.widget), GTK_ORIENTATION_HORIZONTAL), 0,
                          "the column takes the width it is offered")
    }

    func testCountsAreGroupedAsTheLocaleWritesThem() {
        let saved = String(cString: setlocale(LC_NUMERIC, nil))
        defer {
            setlocale(LC_NUMERIC, saved)
        }
        setlocale(LC_NUMERIC, "C")
        XCTAssertEqual(DiffGtkView.grouped(1234567), "1234567", "the C locale has no grouping")
        guard setlocale(LC_NUMERIC, "en_US.UTF-8") != nil else {
            return   // the locale is not installed; the C case still ran
        }
        XCTAssertEqual(DiffGtkView.grouped(1234567), "1,234,567")
        XCTAssertEqual(DiffGtkView.grouped(-12), "-12")
        let filler = (1...1200).map { "line \($0)" }.joined(separator: "\n")
        let view = DiffGtkView(oldText: "a\n" + filler, newText: "b\n" + filler, contextLines: 0)
        XCTAssertEqual(text(children(view)[2]), "\u{22EF} 1,200 unchanged lines")
    }

    func testShowRebuildsOnlyOnAChange() {
        let view = DiffGtkView(oldText: "a\n", newText: "b\n")
        let first = children(view)[0]
        view.show(oldText: "a\n", newText: "b\n")
        XCTAssertEqual(children(view)[0], first, "the same diff keeps its widgets")
        view.show(oldText: "a\n", newText: "c\n")
        XCTAssertNotEqual(children(view)[0], first)
        XCTAssertEqual(texts(ofRow: children(view)[1]), ["", "1", "+", "c"])
        view.show(oldText: "a\n", newText: "c\n", contextLines: 0, maxRenderedLines: 1)
        XCTAssertEqual(children(view).count, 2, "a new cap rebuilds: one line and the cut note")
    }
}
