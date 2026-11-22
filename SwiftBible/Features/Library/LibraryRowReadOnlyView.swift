//
//  LibraryRowReadOnlyView.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 2026-11-21.
//

import SwiftUI

/// Read-only Library card: annotation summary, expandable passage, and Note/Tags details
///
/// Used directly (e.g. Search) or wrapped by LibraryRowView, which supplies the
/// trailing control and layers on the write actions (menus, swipe, selection)
struct LibraryRowReadOnlyView<TrailingControl: View>: View {

    // MARK: Properties

    /// Consolidated entry point for required data
    var data: LibraryRowViewData

    /// Shown at the trailing edge of the summary row (empty when read-only)
    let trailingControl: TrailingControl

    // MARK: Properties (Private, Environment)

    /// What is the system Dynamic Type setting?
    @Environment(\.dynamicTypeSize) private var systemDynamicTypeSize

    /// What's our current configured theme?
    @Environment(\.readerTheme) private var readerTheme

    // MARK: Properties (Private, Passage Truncation)

    @ScaledMetric(relativeTo: .body) private var annotationTagsLineHeight: CGFloat = 20

    /// Passage text collapses to this many lines; overflow fades out
    private let passageLineLimit = 3

    /// Line height from resolved Theme
    private var passageLineHeight: CGFloat {
        readerTheme.lineHeight(dynamicTypeSize: scriptureDynamicTypeSize)
    }

    /// Text size from resolved Theme
    private var scriptureDynamicTypeSize: DynamicTypeSize {
        readerTheme.scriptureDynamicTypeSize(for: systemDynamicTypeSize)
    }

    // MARK: Properties (Private, Dynamic Type)

    @ScaledMetric(relativeTo: .body) private var fontSize16: CGFloat = 16
    @ScaledMetric(relativeTo: .body) private var frameSize16: CGFloat = 16

    // MARK: Properties (Private, State)

    /// Full (unclamped) height of the passage text, measured directly
    @State private var unclampedPassageHeight: CGFloat = 0

    /// Has 1 second passed since we first rendered the empty card passage slot?
    @State private var isPassageLoadSpinnerVisible: Bool = false

    /// Has this passage been tapped (to expand)?
    ///
    /// TODO: move up a layer to LibraryView; state that outlives the row's LazyVStack life
    /// should NOT live inside the row itself (is lost on row recycle)
    @State private var isPassageExpanded: Bool = false

    // MARK: Initializers

    init(data: LibraryRowViewData,
         @ViewBuilder trailingControl: () -> TrailingControl) {
        self.data = data
        self.trailingControl = trailingControl()
    }

    // MARK: Properties (Computed)

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

    /// VoiceOver hint describing what a tap will do (empty when the passage can't expand)
    private var passageAccessibilityHint: String {
        guard isPassageTruncated else {
            return ""
        }
        return isPassageExpanded
            ? String(localized: "Collapses the passage", comment: "VoiceOver hint on an expanded Library card passage")
            : String(localized: "Shows the full passage", comment: "VoiceOver hint on a collapsed Library card passage")
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

    // MARK: Views

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Row 1: Annotation summary
            // At accessibility sizes the passage gets the full width on its own lines;
            // squeezed between the icon and the menu, book names broke mid-word
            if systemDynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        annotationTypeIcon
                        Spacer()
                        trailingControl
                    }
                    passageLabels(in: AnyLayout(VStackLayout(alignment: .leading, spacing: 2)))
                }
            } else {
                HStack {
                    annotationTypeIcon
                    passageLabels(in: AnyLayout(HStackLayout(spacing: 8)))
                    Spacer()
                    trailingControl
                }
            }

            // Row 2: Verse rendered text
            if let renderedPassageRuns = data.renderedPassageRuns {
                // Always a Button so view identity stays stable when truncation is first
                // measured; short passages simply ignore taps
                Button {
                    withAnimation(.snappy(duration: 0.35)) {
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
                        if let failure = data.passageLoadFailure {
                            passageLoadFailureMessage(failure)
                        } else if isPassageLoadSpinnerVisible {
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
                    .font(readerTheme.font(fixedSize: fontSize16, weight: .regular))
                    .lineHeight(AttributedString.LineHeight.exact(points: annotationTagsLineHeight)) // try to match AnnotationEditorSheetView Note TextInput
            } else if case .tags(let tags) = data.annotation.content {
                Divider()
                FlowLayout {
                    ForEach(tags, id: \.self) { tag in
                        Button {
                            // nothing
                        } label: {
                            Text(tag)
                                .font(readerTheme.font(.caption, weight: .semibold))
                                .foregroundStyle(Color.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                        }
                        .buttonStyle(.plain)
                        .glassEffect(.regular.tint(.accentColor),
                                     in: .capsule)
                        .allowsHitTesting(false)
                    }
                }
//                ScrollView(.horizontal, showsIndicators: false) {
//                    TwoRowFlowLayout(spacing: 8) {
//
//                    }
//                    .padding(.horizontal, 4)
//                    .padding(.vertical, 2)
//                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(readerTheme.backgroundColor,
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
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
            .dynamicTypeSize(scriptureDynamicTypeSize)
    }

    /// Passage text styling
    private func passageText(for runs: [RenderedPassageRun]) -> some View {
        PassageTextRenderer.text(for: runs,
                                 readerTheme: readerTheme,
                                 dynamicTypeSize: scriptureDynamicTypeSize,
                                 footnoteMarkerMode: .hidden,
                                 produceLinkAttributes: false) // do NOT want these tap events here
        .font(readerTheme.scriptureFont)
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
                bookmarkColor: readerTheme.backgroundColor,
                persistedHighlights: data.annotation.highlightedVerses,
                opacity: 0.5)) // custom for this view only (default 1)
    }

    /// Shown when passage could not be loaded
    private func passageLoadFailureMessage(_ failure: LibraryPassageLoadFailure) -> some View {
        Label {
            switch failure {
            case .offline:
                Text("Connect to the Internet to view this passage.")
            case .failed:
                Text("Unable to load this passage.")
            }
        } icon: {
            Image(systemName: failure == .offline ? "wifi.slash" : "exclamationmark.triangle")
        }
        .font(readerTheme.font(.footnote))
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
    }

    /// Annotation type icon
    // TODO: normalize size
    private var annotationTypeIcon: some View {
        Group {
            switch data.annotation.content {
            case .highlight(_):
                Image(systemName: "pencil.line")
            case .note(_):
                Image(systemName: "text.alignleft")
            case .tags(_):
                Image(systemName: "tag")
            }
        }
        .frame(width: frameSize16, height: frameSize16)
        .font(readerTheme.font(fixedSize: fontSize16, weight: .regular))
        .foregroundStyle(.secondary)
    }

    /// Chapter / verse range / translation, side by side or stacked
    private func passageLabels(in layout: AnyLayout) -> some View {
        layout {
            Text(data.passageLabel)
            Text(data.translationLabel)
                .foregroundStyle(.secondary)
        }
        .font(readerTheme.font(fixedSize: fontSize16, weight: .medium))
        .contentShape(Rectangle())
    }
}

extension LibraryRowReadOnlyView where TrailingControl == EmptyView {

    /// Read-only card with no trailing control
    init(data: LibraryRowViewData) {
        self.init(data: data) { EmptyView() }
    }
}
