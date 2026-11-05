// Sources/DiffView/DiffView.swift
//
// The view half of the STANDALONE diff-viewer component (the model is
// DiffModel.swift): renders a DiffComputer result as a unified line diff -
// old/new line-number gutters, +/- markers, tinted added/removed rows, and
// "N unchanged lines" gaps where context collapsed. Degenerate inputs present
// honestly: identical texts say "No changes", oversized inputs fall back to a
// plain-text preview, and rendering caps at `maxRenderedLines` with an explicit
// truncation note (the diff is a review surface, not a file viewer).
//
// STANDALONE BY DESIGN: imports SwiftUI only - no host framework types - see
// DiffModel.swift for the standalone story (the chat component consumes it,
// ActionUI's Diff element wraps it).

import SwiftUI

public struct DiffView: View {
    let oldText: String
    let newText: String
    var contextLines: Int = 3
    var maxRenderedLines: Int = 300

    // The memberwise initializer is internal, so the public component spells out its
    // initializer explicitly (with the existing defaults) for callers outside this module.
    public init(oldText: String, newText: String, contextLines: Int = 3, maxRenderedLines: Int = 300) {
        self.oldText = oldText
        self.newText = newText
        self.contextLines = contextLines
        self.maxRenderedLines = maxRenderedLines
    }

    public var body: some View {
        let result = DiffComputer.compute(oldText: oldText, newText: newText, context: contextLines)
        VStack(alignment: .leading, spacing: 0) {
            if result.exceedsSizeLimit {
                note(DiffPresentation.tooLargeNote)
                fallbackText
            } else if result.isIdentical {
                note(DiffPresentation.identicalNote)
            } else {
                hunkRows(result)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.05), in: RoundedRectangle(cornerRadius: 6))
        .textSelection(.enabled)
    }

    // MARK: - Hunks

    @ViewBuilder
    private func hunkRows(_ result: DiffResult) -> some View {
        let visible = DiffPresentation.visibleLines(of: result, limit: maxRenderedLines)
        ForEach(result.hunks.prefix(visible.hunkCount)) { hunk in
            if hunk.skippedBefore > 0 {
                gap(hunk.skippedBefore)
            }
            let isLastVisible = hunk.id == visible.hunkCount - 1
            ForEach(isLastVisible ? Array(hunk.lines.prefix(visible.linesInLastHunk)) : hunk.lines) { line in
                row(line)
            }
        }
        if visible.truncatedLineCount > 0 {
            note(DiffPresentation.truncatedNote(visible.truncatedLineCount.formatted()))
        } else if result.trailingSkippedLines > 0 {
            gap(result.trailingSkippedLines)
        }
    }

    // MARK: - Rows

    private func row(_ line: DiffLine) -> some View {
        HStack(alignment: .top, spacing: 0) {
            number(line.oldNumber)
            number(line.newNumber)
            Text(DiffPresentation.marker(line.kind))
                .foregroundStyle(.secondary)
                .frame(width: 14, alignment: .center)
            Text(line.text.isEmpty ? " " : line.text)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(.system(.caption, design: .monospaced))
        .padding(.vertical, 1)
        .background(color(for: line.kind))
    }

    private func number(_ value: Int?) -> some View {
        Text(value.map(String.init) ?? "")
            .foregroundStyle(.secondary)
            .frame(width: 34, alignment: .trailing)
            .padding(.trailing, 4)
    }

    private func gap(_ count: Int) -> some View {
        Text(DiffPresentation.gap(count, count.formatted()))
            .font(.caption2)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 2)
    }

    private func note(_ text: String) -> some View {
        Text(text)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .padding(4)
    }

    private var fallbackText: some View {
        Text(DiffPresentation.fallbackText(newText))
            .font(.system(.caption, design: .monospaced))
            .padding(6)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func color(for kind: DiffLine.Kind) -> Color {
        switch kind {
        case .context:
            return .clear
        case .removed:
            return Color.red.opacity(0.12)
        case .added:
            return Color.green.opacity(0.12)
        }
    }
}
