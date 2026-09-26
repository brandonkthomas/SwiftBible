//
//  LibraryRowView.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 2026-07-19.
//

import SwiftUI

struct LibraryRowView: View {

    // MARK: Properties

    /// Consolidated entry point for required data
    var data: LibraryRowViewData

    // MARK: Properties (Passage Truncation, Private)

    /// Same value used in ReaderPassageView
    /// TODO: Consolidate in central location
    private let passageLineHeight: CGFloat = 30

    /// Passage text collapses to this many lines; overflow fades out
    private let passageLineLimit = 3

    /// Full (unclamped) height of the passage text, measured directly
    @State private var unclampedPassageHeight: CGFloat = 0

    /// Has 1 second passed since we first rendered the empty card passage slot?
    @State private var isPassageLoadSpinnerVisible: Bool = false

    /// Has this passage been tapped (to expand)?
    ///
    /// TODO: move up a layer to LibraryView; state that outlives the row's LazyVStack life
    /// should NOT live inside the row itself (is lost on row recycle)
    @State private var isPassageExpanded: Bool = false

    /// Does the passage need more lines than we display?
    ///
    /// Line height is fixed, so height / lineHeight is the real line count
    /// Rounding absorbs the first line's ascent/descent overshoot
    private var isPassageTruncated: Bool {
        Int((unclampedPassageHeight / passageLineHeight).rounded()) > passageLineLimit
    }

    /// Fade the bottom edge only while overflowing text is hidden
    private var isPassageFaded: Bool {
        isPassageTruncated && !isPassageExpanded
    }

    // MARK: Views

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Row 1: Annotation summary
            HStack {
                // Annotation type icon
                // TODO: enforce width & normalize size
                Group {
                    switch data.annotation.content {
                    case .highlight(_):
                        Image(systemName: "pencil.line")
                            .symbolRenderingMode(.palette)
//                            .foregroundStyle(.primary, color.uiColor)
                    case .note(_):
                        Image(systemName: "text.alignleft")
                    case .tags(_):
                        Image(systemName: "tag")
                    }
                }
                .font(.system(size: 16, weight: .regular, design: .serif))
                .foregroundStyle(.secondary)

                // Chapter / verse range / translation
                HStack(spacing: 8) {
                    Text(data.passageLabel)
                    Text(data.translationLabel)
                        .foregroundStyle(.secondary)
                }
                .font(.system(size: UIFontMetrics(forTextStyle: .body).scaledValue(for: 16),
                              weight: .medium,
                              design: .serif))
                .contentShape(Rectangle())

                Spacer()

                // Action menu
                annotationItemMenu
                // TODO: hitbox is TINY
//                .frame(maxHeight: )
            }

            // Row 2: Verse rendered text
            if let renderedPassageRuns = data.renderedPassageRuns {
                // Always a Button so view identity stays stable when truncation is first
                // measured; short passages simply ignore taps
                Button {
                    withAnimation(.snappy) {
                        isPassageExpanded.toggle()
                    }
                } label: {
                    passage(for: renderedPassageRuns)
                }
                // borderless: inside a LazyVStack, confines the tap to the label instead of the whole row
                .buttonStyle(.borderless)
                // Only listen for taps when truncated
                .allowsHitTesting(isPassageTruncated)
                // accessibility compat
                .accessibilityRemoveTraits(isPassageTruncated ? [] : .isButton)
                .accessibilityHint(passageAccessibilityHint)
            // Row 2: Verse rendered text (loading state)
            } else {
                Color.clear
                    .frame(height: collapsedPassageHeight)
                    .overlay {
                        if isPassageLoadSpinnerVisible {
                            ProgressView()
                                .accessibilityLabel("Loading passage...")
                        }
                    }
                    // task cancelled when LazyVStack rebuilds this row (i.e. scroll offscreen)
                    .task {
                        try? await Task.sleep(for: .seconds(1))
                        // have we been asked to cancel while sleeping?
                        guard !Task.isCancelled else { return }
                        // now we're safe to run logic
                        isPassageLoadSpinnerVisible = true
                    }
            }

            // Row 3: Annotation details (need to present Note/Tags ONLY)
            // switch doesnt work here due to exhaustive complaints
            if case .note(let noteText) = data.annotation.content {
                Divider()
                Text(noteText)
                    .font(.system(size: UIFontMetrics(forTextStyle: .body).scaledValue(for: 16),
                                  weight: .regular,
                                  design: .serif))
                    .lineHeight(AttributedString.LineHeight.exact(points: 20)) // try to match AnnotationEditorSheetView Note TextInput
            } else if case .tags(let tags) = data.annotation.content {
                Divider()
                Text(tags.joined(separator: ", "))
                    .font(.system(size: UIFontMetrics(forTextStyle: .body).scaledValue(for: 16),
                                  weight: .regular,
                                  design: .serif))
                    .lineHeight(AttributedString.LineHeight.exact(points: 20)) // try to match AnnotationEditorSheetView Note TextInput
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

    /// VoiceOver hint describing what a tap will do (empty when the passage can't expand)
    private var passageAccessibilityHint: String {
        guard isPassageTruncated else {
            return ""
        }
        return isPassageExpanded ? "Collapses the passage" : "Shows the full passage"
    }

    /// Height of the collapsed passage (also used by the loading placeholder)
    private var collapsedPassageHeight: CGFloat {
        passageLineHeight * CGFloat(passageLineLimit)
    }

    /// Height the passage is clipped to
    ///
    /// Collapsed is the default *before* measuring too: rows that first appeared at full
    /// height then snapped to 3 lines would shift everything below it, and LazyVStack
    /// re-creates rows while scrolling up, so the list would jump repeatedly
    private var visiblePassageHeight: CGFloat {
        // not measured yet (0): assume collapsed
        guard unclampedPassageHeight > 0 else {
            return collapsedPassageHeight
        }
        // short passages and expanded passages show their full height
        guard isPassageTruncated, !isPassageExpanded else {
            return unclampedPassageHeight
        }
        return collapsedPassageHeight
    }

    /// Visible passage: clipped to 3 lines unless expanded, with a bottom fade while clipped
    ///
    /// The text always lays out every line, so wrapping never changes when expanding
    /// Only the clipping frame's height changes, which animates as a clean reveal
    /// (animating lineLimit instead re-wraps the text and moves glyphs mid-animation)
    private func passage(for renderedPassageRuns: [RenderedPassageRun]) -> some View {
        passageText(for: renderedPassageRuns)
            // Full natural height, never compressed by the frame below
            .fixedSize(horizontal: false, vertical: true)
            // Measure the full text directly (no hidden copy needed)
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.size.height
            } action: { height in
                unclampedPassageHeight = height
            }
            .frame(height: visiblePassageHeight, alignment: .top)
            .clipped()
            .mask(alignment: .top) {
                // One gradient in both states (no if/else) so identity never changes;
                // only the final stop's color does
                LinearGradient(
                    stops: [
                        .init(color: .black, location: 0),
                        .init(color: .black, location: 0.6),
                        .init(color: isPassageFaded ? .clear : .black, location: 1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
    }

    /// Passage text styling
    private func passageText(for runs: [RenderedPassageRun]) -> some View {
        PassageTextRenderer.text(for: runs,
                                 footnoteMarkerMode: .hidden,
                                 produceLinkAttributes: false) // do NOT want these tap events here
            .font(.system(.body, design: .serif))
            .lineHeight(AttributedString.LineHeight.exact(points: passageLineHeight))
            // Button labels center multi-line text by default
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            // custom TextRenderer to support verse highlights w/ animations
            .textRenderer(VerseHighlightRenderer(
                settledVerses: nil,
                revealingVerses: nil,
                fadingVerses: nil,
                tapOrigin: nil,
                progress: 0,
                fadeProgress: 0,
                persistedHighlights: data.annotation.highlightedVerses,
                opacity: 0.5)) // custom for this view only (default 1)
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
    let repository = FakeBibleRepository()
    let passageStore = BiblePassageStore(repository: repository,
                                         passageCache: InMemoryPassageCache())
    let libraryStore = LibraryStore(libraryRepository: InMemoryLibraryRepository(),
                                    passageStore: passageStore)
    let catalogStore = BibleCatalogStore(repository: repository)
    LibraryRowViewPreviewHost(libraryStore: libraryStore,
                              catalogStore: catalogStore)
}

/// Preview-only host: loads each sample's passage before building its `LibraryRowViewData`,
/// mirroring the real load path in LibraryView
private struct LibraryRowViewPreviewHost: View {
    let libraryStore: LibraryStore
    let catalogStore: BibleCatalogStore

    private let annotations = [
        PreviewFixtures.sampleHighlightAnnotation,
        PreviewFixtures.sampleNoteAnnotation,
        PreviewFixtures.sampleTagsAnnotation
    ]

    var body: some View {
        VStack(spacing: 16) {
            ForEach(annotations) { annotation in
                LibraryRowView(data: LibraryRowViewData(annotation: annotation,
                                                        catalogStore: catalogStore,
                                                        libraryStore: libraryStore))
            }
        }
        .padding()
        .background(Color(.systemGroupedBackground))
        .task {
            for annotation in annotations {
                await libraryStore.loadPassage(for: annotation)
            }
        }
    }
}
