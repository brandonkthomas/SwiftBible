//
//  LibraryRowView.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 2026-07-19.
//

import SwiftUI

struct LibraryRowView: View {

    var annotation: VerseAnnotation
    let passageLabel: String
    let translationLabel: String

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

            // TODO: Verse rendered text
//            let passage = try! PassageHTMLParser().parse(html: FakeBibleRepository.footnotePassageHTML)
//            PassageTextRenderer.text(for: passage.runs(for: verseRange),
//                                          mode: .inline)
            Text("\(annotation)")

            Divider()

            // Annotation type
            annotationItemContent(for: annotation)

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

    private func annotationItemContent(for annotation: VerseAnnotation) -> some View {
        switch annotation.content {
        case .highlight(let color):
            Text(color.rawValue)
        case .note(let noteText):
            Text(noteText)
        case .tags(let tags):
            Text(tags.joined(separator: ", "))
        }
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
                       passageLabel: "Genesis 1:1",
                       translationLabel: "NIV")
        LibraryRowView(annotation: PreviewFixtures.sampleNoteAnnotation,
                       passageLabel: "Genesis 1:1–2",
                       translationLabel: "NIV")
        LibraryRowView(annotation: PreviewFixtures.sampleTagsAnnotation,
                       passageLabel: "Genesis 1:1–3",
                       translationLabel: "NIV")
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
