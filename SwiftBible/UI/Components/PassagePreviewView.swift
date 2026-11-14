//
//  PassagePreviewView.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 2026-11-13.
//

import SwiftUI

/// Non-interactive, decorative rendering of a passage
///
/// Renders paragraphs with the reader's text pipeline (PassageTextRenderer +
/// VerseHighlightRenderer) but without links or gestures. Optional behaviors:
/// - `scrolls`: slowly scrolls upward forever, cycling the passage's paragraphs
/// - `highlights`: every ~4s, selects then deselects 1-3 random fully visible verses
///
/// Both behaviors stop when Reduce Motion is on.
struct PassagePreviewView: View {

    // MARK: Types

    nonisolated enum Style: Equatable {
        /// Fixed-height rounded window w/ the theme background
        case window(height: CGFloat)
        /// Fills available space and extends under bars/safe areas; no background
        case fill
    }

    // MARK: Types (Private)

    /// One laid-out paragraph; recycled from the top, appended at the bottom when scrolling
    nonisolated private struct LaidOutParagraph: Identifiable {
        /// Increases forever; also picks the source paragraph (id % source count)
        let id: Int
        let style: RenderedParagraphStyle
        let runs: [RenderedPassageRun]
        /// nil when the paragraph has no verse runs
        let verseRange: ClosedRange<Int>?
    }

    /// Size of the passage area + the band of it not covered by bars
    nonisolated private struct Viewport: Equatable {
        /// Full height, including top/bottom safe areas (.fill only)
        var height: CGFloat = 0
        /// Y range (passage coordinates) between the navigation bar and tab bar
        var visibleRange: ClosedRange<CGFloat> = 0...0
    }

    // MARK: Properties

    /// Passage to display
    var renderedPassage: RenderedPassage

    /// Theme override; falls back to the environment's reader theme when nil
    var readerTheme: ReaderThemeResolved?

    /// Footnote marker style
    var footnoteMarkerMode: PassageTextRenderer.MarkerMode

    var style: Style

    /// Slowly scroll upward forever
    var scrolls: Bool

    /// Periodically select + deselect random visible verses
    var highlights: Bool

    // MARK: Properties (System Env, Private)

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Current configured theme (used when no readerTheme override is passed in)
    @Environment(\.readerTheme) private var environmentReaderTheme

    // MARK: Properties (Private, Dynamic Type)

    /// Same value used in ReaderPassageView + LibraryRowView
    @ScaledMetric(relativeTo: .body) private var passageLineHeight: CGFloat = 30

    // MARK: Properties (Highlight Animation, Private)

    /// Mirrors ReaderPassageView's VerseHighlightRenderer state
    @State private var revealProgress: CGFloat = 0
    @State private var fadeProgress: CGFloat = 1
    @State private var revealingVerses: ClosedRange<Int>?
    @State private var fadingVerses: ClosedRange<Int>?

    // MARK: Properties (Scrolling, Private)

    /// Paragraphs after recycling has started; nil = the passage's own paragraphs
    @State private var cycledParagraphs: [LaidOutParagraph]?

    /// Measured height of each laid-out paragraph, keyed by LaidOutParagraph.id
    @State private var paragraphHeights: [Int: CGFloat] = [:]

    /// Total height of paragraphs removed from the top; subtracted from the scroll offset
    /// so removing a paragraph doesn't move the remaining text
    @State private var removedHeight: CGFloat = 0

    /// Scroll offset is calculated from time elapsed since this date
    @State private var scrollStartDate: Date = .now

    @State private var viewport = Viewport()

    // MARK: Properties (Static, Private)

    /// Scroll speed (points per second)
    private static let scrollSpeed: CGFloat = 8

    /// Starting scroll offset so the passage already runs past the top edge
    private static let initialScrollOffset: CGFloat = 120

    /// Extra distance past the edges before a paragraph is removed/added,
    /// so blurred edges never appear on screen
    private static let recycleMargin: CGFloat = 60

    /// Time a selection stays on screen (reveal + hold + fade), with some slack
    private static let selectionLifetime: CGFloat = 4

    // MARK: Init

    init(renderedPassage: RenderedPassage,
         readerTheme: ReaderThemeResolved? = nil,
         footnoteMarkerMode: PassageTextRenderer.MarkerMode = .collapsed,
         style: Style = .window(height: 160),
         scrolls: Bool = false,
         highlights: Bool = false) {
        self.renderedPassage = renderedPassage
        self.readerTheme = readerTheme
        self.footnoteMarkerMode = footnoteMarkerMode
        self.style = style
        self.scrolls = scrolls
        self.highlights = highlights
    }

    /// Build a single-paragraph passage from plain verse strings, numbered from `startingVerse`
    init(verses: [String],
         startingVerse: Int = 1,
         readerTheme: ReaderThemeResolved? = nil,
         style: Style = .window(height: 160),
         scrolls: Bool = false,
         highlights: Bool = false) {
        let paragraph = RenderedParagraph(verses: verses, startingVerse: startingVerse)

        self.init(renderedPassage: RenderedPassage(paragraphs: [paragraph], footnotes: []),
                  readerTheme: readerTheme,
                  footnoteMarkerMode: .hidden,
                  style: style,
                  scrolls: scrolls,
                  highlights: highlights)
    }

    // MARK: Properties (Computed, Private)

    private var windowHeight: CGFloat? {
        switch style {
        case .window(let height): height
        case .fill: nil
        }
    }

    /// Space above the first paragraph (window only; .fill scrolls past the top edge)
    private var contentTopInset: CGFloat {
        style == .fill ? 0 : 10
    }

    private var paragraphs: [LaidOutParagraph] {
        cycledParagraphs ?? (0..<renderedPassage.paragraphs.count).map {
            Self.laidOutParagraph(id: $0, from: renderedPassage)
        }
    }

    // MARK: Views

    var body: some View {
        let themeResolved = readerTheme ?? environmentReaderTheme

        // Built once per body evaluation; the TimelineView below only moves it each frame
        let paragraphsView = passageParagraphs(theme: themeResolved)

        ZStack {
            TimelineView(.animation(paused: !scrolls || reduceMotion)) { context in
                Color.clear
                    .overlay(alignment: .top) {
                        paragraphsView
                            .padding(.top, contentTopInset)
                            .offset(y: -scrollOffset(at: context.date))
                    }
            }
            .background(windowHeight == nil ? Color.clear : themeResolved.backgroundColor)
            .clipShape(.rect(cornerRadius: windowHeight == nil ? 0 : 10))
            .ignoresSafeArea(edges: style == .fill ? .all : [])
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .frame(height: windowHeight)
        .glassEffect(windowHeight == nil ? .identity : .clear, in: .rect(cornerRadius: 10))
        // .fill: safe area insets = bars; the passage ignores them, so its coordinates
        // start at the top of the screen
        .onGeometryChange(for: Viewport.self) { proxy in
            let insets = style == .fill ? proxy.safeAreaInsets : EdgeInsets()
            return Viewport(height: insets.top + proxy.size.height + insets.bottom,
                            visibleRange: insets.top...(insets.top + proxy.size.height))
        } action: { newViewport in
            viewport = newViewport
        }
        .allowsHitTesting(false)
        .accessibilityElement(children: .combine)
        .onChange(of: renderedPassage.paragraphs) {
            resetScrolling()
        }
        .task {
            await runHighlightLoop()
        }
        .task {
            await runPassageRecycler()
        }
    }

    private func passageParagraphs(theme: ReaderThemeResolved) -> some View {
        VStack(spacing: 0) {
            ForEach(paragraphs) { paragraph in
                PassageTextRenderer.text(for: paragraph.runs,
                                         readerTheme: theme,
                                         footnoteMarkerMode: footnoteMarkerMode,
                                         produceLinkAttributes: false) // decorative; no taps
                    .padding(.leading, PassageTextRenderer.leadingPadding(for: paragraph.style))
                    .textRenderer(VerseHighlightRenderer(
                        settledVerses: nil,
                        revealingVerses: revealingVerses,
                        fadingVerses: fadingVerses,
                        tapOrigin: nil,
                        progress: revealProgress,
                        fadeProgress: fadeProgress,
                        bookmarkColor: theme.backgroundColor,
                        persistedHighlights: [:]))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    // spacing lives in padding (not VStack spacing) so measured heights include it
                    .padding(EdgeInsets(top: 2, leading: 16, bottom: 10, trailing: 16))
                    .onGeometryChange(for: CGFloat.self) { proxy in
                        proxy.size.height
                    } action: { height in
                        paragraphHeights[paragraph.id] = height
                    }
            }
        }
        .font(.system(.body, design: theme.fontDesign))
        .fontWeight(theme.fontWeight)
        .lineHeight(AttributedString.LineHeight.exact(points: passageLineHeight))
        .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: Functions (Private, Highlights)

    /// Select + deselect random verse ranges every ~4s
    ///
    /// Runs until .task cancels it (view disappears); Task.sleep throws on cancellation
    private func runHighlightLoop() async {
        guard highlights, !reduceMotion else { return }

        do {
            while true {
                try await Task.sleep(for: .seconds(1))
                guard let verses = randomVisibleVerseRange() else {
                    // nothing fully visible; try again next cycle
                    try await Task.sleep(for: .seconds(3))
                    continue
                }
                selectVerses(verses)

                try await Task.sleep(for: .seconds(3))
                deselectVerses()
            }
        } catch {
            // cancelled; nothing to clean up
        }
    }

    /// Same reveal sequence as ReaderPassageView.handleVerseSelection()
    private func selectVerses(_ verses: ClosedRange<Int>) {
        revealingVerses = verses
        revealProgress = 0
        withAnimation(.snappy(duration: 0.35)) {
            revealProgress = 1
        }
    }

    /// Same fade sequence as ReaderPassageView.fadeOutVerses()
    private func deselectVerses() {
        guard let verses = revealingVerses else { return }

        fadingVerses = verses
        revealingVerses = nil
        fadeProgress = 1
        withAnimation(.snappy(duration: 0.35)) {
            fadeProgress = 0
        } completion: {
            fadingVerses = nil
        }
    }

    /// 1–3 consecutive verses from paragraphs fully inside the visible band, or nil if none are
    ///
    /// When scrolling, the top edge is pushed down by the distance the text scrolls during
    /// one selection, so a selected paragraph stays fully visible until it fades out
    private func randomVisibleVerseRange() -> ClosedRange<Int>? {
        let scrollAllowance = scrolls ? Self.scrollSpeed * Self.selectionLifetime : 0
        let visibleTop = viewport.visibleRange.lowerBound + scrollAllowance
        let visibleBottom = viewport.visibleRange.upperBound

        var paragraphTop = contentTopInset - scrollOffset(at: .now)
        var visibleRanges: [ClosedRange<Int>] = []

        for paragraph in paragraphs {
            guard let height = paragraphHeights[paragraph.id] else { break }

            if let verseRange = paragraph.verseRange,
               paragraphTop >= visibleTop && paragraphTop + height <= visibleBottom {
                visibleRanges.append(verseRange)
            }
            paragraphTop += height
        }

        // Visible paragraphs are contiguous, so their verses form one range
        // and a selection may cross a paragraph break
        guard let firstVerse = visibleRanges.map(\.lowerBound).min(),
              let lastVerse = visibleRanges.map(\.upperBound).max() else {
            return nil
        }

        let length = Int.random(in: 1...min(3, lastVerse - firstVerse + 1))
        let start = Int.random(in: firstVerse...(lastVerse - length + 1))
        return start...(start + length - 1)
    }

    // MARK: Functions (Private, Scrolling)

    /// Distance from the top of the first laid-out paragraph to the top of the passage area
    private func scrollOffset(at date: Date) -> CGFloat {
        guard scrolls else { return 0 }

        let elapsed = reduceMotion ? 0 : CGFloat(date.timeIntervalSince(scrollStartDate))
        return Self.initialScrollOffset + Self.scrollSpeed * elapsed - removedHeight
    }

    /// Start over from the passage's own paragraphs (passage changed)
    private func resetScrolling() {
        cycledParagraphs = nil
        paragraphHeights = [:]
        removedHeight = 0
        scrollStartDate = .now
    }

    /// Recycle paragraphs twice a second until .task cancels it
    private func runPassageRecycler() async {
        guard scrolls else { return }

        do {
            while true {
                recyclePassageParagraphs()
                try await Task.sleep(for: .milliseconds(500))
            }
        } catch {
            // cancelled; nothing to clean up
        }
    }

    /// Remove paragraphs scrolled fully above the top edge; append one when the
    /// bottom of the passage gets close to the bottom edge
    private func recyclePassageParagraphs() {
        guard viewport.height > 0, !renderedPassage.paragraphs.isEmpty else { return }

        var current = paragraphs
        var changed = false
        var offset = scrollOffset(at: .now)

        // Remove from top. removedHeight grows by the same amount in the same update,
        // so the remaining paragraphs stay where they are on screen
        while current.count > 1,
              let first = current.first,
              let height = paragraphHeights[first.id],
              height + Self.recycleMargin < offset {
            current.removeFirst()
            paragraphHeights[first.id] = nil
            removedHeight += height
            offset -= height
            changed = true
        }

        // Append to bottom; wait until every paragraph has been measured
        let heights = current.compactMap { paragraphHeights[$0.id] }
        if heights.count == current.count,
           let lastParagraph = current.last,
           heights.reduce(0, +) - offset < viewport.height + Self.recycleMargin {
            current.append(Self.laidOutParagraph(id: lastParagraph.id + 1, from: renderedPassage))
            changed = true
        }

        // avoid re-rendering every tick when nothing moved
        if changed {
            cycledParagraphs = current
        }
    }

    // MARK: Functions (Static, Private)

    /// Build laid-out paragraph `id`: cycles through the passage's paragraphs with verse
    /// numbers that keep increasing, so every laid-out verse number is unique for highlighting
    nonisolated private static func laidOutParagraph(id: Int,
                                                     from passage: RenderedPassage) -> LaidOutParagraph {
        let source = passage.paragraphs[id % passage.paragraphs.count]
        let cycle = id / passage.paragraphs.count

        // shift by the passage's last verse number so cycles never overlap
        let lastVerse = passage.paragraphs.flatMap(\.runs)
            .compactMap { $0.verseRange.map { $0.endVerse ?? $0.startVerse } }
            .max() ?? 0
        let runs = source.runs.map { shifted($0, by: cycle * lastVerse) }

        let verseRanges = runs.compactMap(\.verseRange)
        var verseRange: ClosedRange<Int>?
        if let firstVerse = verseRanges.map(\.startVerse).min(),
           let lastVerse = verseRanges.map({ $0.endVerse ?? $0.startVerse }).max() {
            verseRange = firstVerse...lastVerse
        }

        return LaidOutParagraph(id: id,
                                style: source.style,
                                runs: runs,
                                verseRange: verseRange)
    }

    /// Run with its verse numbers (and verse label text) moved forward by `shift`
    nonisolated private static func shifted(_ run: RenderedPassageRun,
                                            by shift: Int) -> RenderedPassageRun {
        guard shift != 0 else { return run }

        func shifted(_ verseRange: RenderedVerseRange) -> RenderedVerseRange {
            RenderedVerseRange(startVerse: verseRange.startVerse + shift,
                               endVerse: verseRange.endVerse.map { $0 + shift })
        }

        switch run {
        case .text(let text, verseRange: let verseRange):
            return .text(text, verseRange: verseRange.map(shifted))
        case .styledText(let text, style: let style, verseRange: let verseRange):
            return .styledText(text, style: style, verseRange: verseRange.map(shifted))
        case .verseLabel(displayText: let displayText, verseRange: let verseRange):
            guard let verseRange else {
                return .verseLabel(displayText: displayText, verseRange: nil)
            }
            let newRange = shifted(verseRange)
            return .verseLabel(displayText: newRange.displayText, verseRange: newRange)
        case .footnoteMarker(let footnoteID, verseRange: let verseRange):
            return .footnoteMarker(footnoteID, verseRange: shifted(verseRange))
        }
    }
}

// MARK: Xcode Canvas Previews

#Preview("Window") {
    VStack(spacing: 16) {
        PassagePreviewView(verses: [
            "In the beginning, God created the heavens and the earth.",
            "The earth was without form and void, and darkness was over the face of the deep.",
            "And God said, “Let there be light,” and there was light.",
            "And God saw that the light was good. And God separated the light from the darkness."
        ])

        PassagePreviewView(verses: [
            "In the beginning was the Word, and the Word was with God, and the Word was God.",
            "He was in the beginning with God.",
        ],
                           readerTheme: .init(basePreset: .ink),
                           style: .window(height: 100),
                           highlights: true)
    }
    .padding()
}

#Preview("Fill, scrolling + highlights") {
    PassagePreviewView(verses: [
        "In the beginning, God created the heavens and the earth.",
        "The earth was without form and void, and darkness was over the face of the deep.",
        "And God said, “Let there be light,” and there was light.",
        "And God saw that the light was good. And God separated the light from the darkness."
    ],
                       style: .fill,
                       scrolls: true,
                       highlights: true)
}
