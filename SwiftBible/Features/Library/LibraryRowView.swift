//
//  LibraryRowView.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 2026-07-19.
//

import SwiftUI

struct LibraryRowView: View {

    var annotation: VerseAnnotation
    let renderedPassageRuns: [RenderedPassageRun]?
    let passageLabel: String
    let translationLabel: String

    // MARK: Properties (Passage Truncation, Private)

    /// Same value used in ReaderPassageView
    private let passageLineHeight: CGFloat = 30

    /// Passage text collapses to this many lines; overflow fades out
    private let passageLineLimit = 3

    /// Full (unclamped) height of the passage text, measured off-screen
    @State private var unclampedPassageHeight: CGFloat = 0

    /// Does the passage need more lines than we display?
    ///
    /// Line height is fixed, so height / lineHeight is the real line count
    /// Rounding absorbs the first line's ascent/descent overshoot
    private var isPassageTruncated: Bool {
        Int((unclampedPassageHeight / passageLineHeight).rounded()) > passageLineLimit
    }

    var body: some View {
        // build this annotation into a card
        VStack(alignment: .leading, spacing: 10) {
            // Chapter / verse range / translation
            HStack {
                Text(passageLabel)
                    .font(.system(.headline))
                Text(translationLabel)
                    .font(.system(.body))
            }

            // Verse rendered text
            if let renderedPassageRuns {
                passageText(for: renderedPassageRuns)
                    .lineLimit(passageLineLimit)
                    .background(alignment: .top) {
                        // Hidden unclamped copy of the same text
                        // Visible copy is already capped at passageLineLimit,
                        // This copy lays out at the same width with its ideal height
                        passageText(for: renderedPassageRuns)
                            .fixedSize(horizontal: false, vertical: true)
                            .hidden()
                            .onGeometryChange(for: CGFloat.self) { proxy in
                                proxy.size.height
                            } action: { height in
                                unclampedPassageHeight = height
                            }
                    }
                    .mask(alignment: .top) {
                        if isPassageTruncated {
                            // Mask alpha from gradient
                            LinearGradient(
                                stops: [
                                    .init(color: .black, location: 0),
                                    .init(color: .black, location: 0.6),
                                    .init(color: .clear, location: 1)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        } else {
                            Rectangle()
                        }
                    }
            }

            // Annotation type
            // switch doesnt work here due to exhaustive complaints
            if case .note(let noteText) = annotation.content {
                Divider()
                Text(noteText)
            } else if case .tags(let tags) = annotation.content {
                Divider()
                Text(tags.joined(separator: ", "))
            }

            Divider()

            // Annotation actions
            HStack {
                annotationItemType(for: annotation)
                Spacer()
                annotationItemMenu
            }

            // TODO: Date; pending view refactor

            // TODO: limit verse text to 2 lines w/ ellipsis,
            // move tag/note to own full line,
            // move date (small) to annotationItemType
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
    }

    /// Passage text styling, shared by the visible copy and the measuring copy
    /// so both lay out identically
    private func passageText(for runs: [RenderedPassageRun]) -> some View {
        PassageTextRenderer.text(for: runs,
                                 footnoteMarkerMode: .hidden)
            .font(.system(.body, design: .serif))
            .lineHeight(AttributedString.LineHeight.exact(points: passageLineHeight))
            .frame(maxWidth: .infinity, alignment: .leading)
            // custom TextRenderer to support verse highlights w/ animations
            .textRenderer(VerseHighlightRenderer(
                settledVerses: nil,
                revealingVerses: nil,
                fadingVerses: nil,
                tapOrigin: nil,
                progress: 0,
                fadeProgress: 0,
                persistedHighlights: annotation.highlightedVerses))
    }

    private func annotationItemType(for annotation: VerseAnnotation) -> some View {
        HStack {
            switch annotation.content {
            case .highlight(let color):
                Image(systemName: "pencil.line")
                    .font(.system(size: UIFontMetrics(forTextStyle: .body).scaledValue(for: 20)))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.primary, color.uiColor)
            case .note(_):
                Image(systemName: "bookmark")
                    .font(.system(size: UIFontMetrics(forTextStyle: .body).scaledValue(for: 20)))
            case .tags(_):
                Image(systemName: "tag")
                    .font(.system(size: UIFontMetrics(forTextStyle: .body).scaledValue(for: 20)))
            }

            Group {
                switch annotation.content {
                case .highlight:
                    Text("Highlight")
                case .note(_):
                    Text("Note")
                case .tags(let tags):
                    Text("Tag\(tags.count == 1 ? "" : "s")")
                }
            }
            .font(.system(.subheadline))
            .foregroundStyle(Color(.label))
        }
    }

    private var annotationItemMenu: some View {
        Menu {
            Button {

            } label: {
                Label("Test", systemImage: "plus")
            }
            Button {

            } label: {
                Label("Test", systemImage: "plus")
            }
            Button {

            } label: {
                Label("Test", systemImage: "plus")
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: UIFontMetrics(forTextStyle: .body).scaledValue(for: 20)))
                .foregroundStyle(Color(.label))
        }
    }
}

// MARK: Xcode Canvas Previews

#Preview {
    VStack(spacing: 16) {
        LibraryRowView(annotation: PreviewFixtures.sampleHighlightAnnotation,
                       renderedPassageRuns: nil, // TBD
                       passageLabel: "Genesis 1:1",
                       translationLabel: "NIV")
        LibraryRowView(annotation: PreviewFixtures.sampleNoteAnnotation,
                       renderedPassageRuns: nil, // TBD
                       passageLabel: "Genesis 1:1–2",
                       translationLabel: "NIV")
        LibraryRowView(annotation: PreviewFixtures.sampleTagsAnnotation,
                       renderedPassageRuns: nil, // TBD
                       passageLabel: "Genesis 1:1–3",
                       translationLabel: "NIV")
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
