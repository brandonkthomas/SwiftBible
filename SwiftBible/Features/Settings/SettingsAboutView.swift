//
//  SettingsAboutView.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 2026-11-05.
//

import SwiftUI

struct SettingsAboutView: View {

    // MARK: Types (Private)

    /// One paragraph of the endlessly scrolling background passage
    nonisolated private struct BackgroundParagraph: Identifiable {
        /// Increases forever; also picks the source paragraph (id % source count)
        let id: Int
        let runs: [RenderedPassageRun]
        let verseRange: ClosedRange<Int>
    }

    /// Size of the background passage area + the band of it not covered by bars
    nonisolated private struct PassageViewport: Equatable {
        /// Full height, including top/bottom safe areas
        var height: CGFloat = 0
        /// Y range (background passage coordinates) between the navigation bar and tab bar
        var visibleRange: ClosedRange<CGFloat> = 0...0
    }

    // MARK: Properties (System Env, Private)

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: Properties (Private, Dynamic Type)

    @ScaledMetric(relativeTo: .body) private var imageSize44: CGFloat = 44
    @ScaledMetric(relativeTo: .body) private var imageSize72: CGFloat = 72
    @ScaledMetric(relativeTo: .body) private var imageSize96: CGFloat = 96

    /// Same value used in ReaderPassageView + LibraryRowView
    @ScaledMetric(relativeTo: .body) private var passageLineHeight: CGFloat = 30

    // MARK: Properties (Private)

    /// Picked once per appearance; a computed property would re-roll on every
    /// body evaluation (each background animation state change)
    @State private var createdVerb: String = Self.createdVerbs.randomElement() ?? Self.createdVerbs[0]

    // MARK: Properties (Background Passage Animation, Private)

    /// Background passage starts invisible, then fades in
    @State private var backgroundOpacity: CGFloat = 0

    /// Mirrors ReaderPassageView's VerseHighlightRenderer state
    @State private var revealProgress: CGFloat = 0
    @State private var fadeProgress: CGFloat = 1
    @State private var revealingVerses: ClosedRange<Int>?
    @State private var fadingVerses: ClosedRange<Int>?

    // MARK: Properties (Background Passage Scrolling, Private)

    /// Paragraphs currently laid out; recycled from the top, appended at the bottom
    @State private var paragraphs: [BackgroundParagraph] =
        (0..<Self.loremIpsumVerses.count).map(Self.backgroundParagraph(id:))

    /// Measured height of each laid-out paragraph, keyed by BackgroundParagraph.id
    @State private var paragraphHeights: [Int: CGFloat] = [:]

    /// Total height of paragraphs removed from the top; subtracted from the scroll offset
    /// so removing a paragraph doesn't move the remaining text
    @State private var removedHeight: CGFloat = 0

    /// Scroll offset is calculated from time elapsed since this date
    @State private var scrollStartDate: Date = .now

    @State private var viewport = PassageViewport()

    // MARK: Properties (Static, Private)

    private static let createdVerbs = ["Created", "Hand-crafted", "Built"]

    /// Scroll speed of the background passage (points per second)
    private static let scrollSpeed: CGFloat = 8

    /// Starting scroll offset so the passage already runs past the top edge
    private static let initialScrollOffset: CGFloat = 120

    /// Extra distance past the screen edges before a paragraph is removed/added,
    /// so blurred edges never appear on screen
    private static let recycleMargin: CGFloat = 60

    /// Time a selection stays on screen (reveal + hold + fade), with some slack
    private static let selectionLifetime: CGFloat = 4

    /// Hardcoded placeholder passage; each inner array is one paragraph, each string one verse
    nonisolated private static let loremIpsumVerses: [[String]] = [
        [
            "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.",
            "Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat.",
            "Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur.",
            "Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.",
        ],
        [
            "Sed ut perspiciatis unde omnis iste natus error sit voluptatem accusantium doloremque laudantium, totam rem aperiam.",
            "Eaque ipsa quae ab illo inventore veritatis et quasi architecto beatae vitae dicta sunt explicabo.",
            "Nemo enim ipsam voluptatem quia voluptas sit aspernatur aut odit aut fugit, sed quia consequuntur magni dolores eos.",
            "Neque porro quisquam est, qui dolorem ipsum quia dolor sit amet, consectetur, adipisci velit.",
        ],
        [
            "Ut enim ad minima veniam, quis nostrum exercitationem ullam corporis suscipit laboriosam, nisi ut aliquid ex ea commodi consequatur.",
            "Quis autem vel eum iure reprehenderit qui in ea voluptate velit esse quam nihil molestiae consequatur.",
            "Vel illum qui dolorem eum fugiat quo voluptas nulla pariatur.",
            "At vero eos et accusamus et iusto odio dignissimos ducimus qui blanditiis praesentium voluptatum deleniti atque corrupti.",
        ],
        [
            "Quos dolores et quas molestias excepturi sint occaecati cupiditate non provident, similique sunt in culpa.",
            "Et harum quidem rerum facilis est et expedita distinctio.",
            "Nam libero tempore, cum soluta nobis est eligendi optio cumque nihil impedit quo minus id quod maxime placeat facere possimus.",
            "Omnis voluptas assumenda est, omnis dolor repellendus.",
        ],
        [
            "Temporibus autem quibusdam et aut officiis debitis aut rerum necessitatibus saepe eveniet ut et voluptates repudiandae sint.",
            "Itaque earum rerum hic tenetur a sapiente delectus, ut aut reiciendis voluptatibus maiores alias consequatur aut perferendis.",
            "Doloribus asperiores repellat, lorem ipsum dolor sit amet, consectetur adipiscing elit.",
            "Integer posuere erat a ante venenatis dapibus posuere velit aliquet.",
        ],
    ]

    /// Verse numbers covered by each paragraph in loremIpsumVerses (1-based, continuous)
    nonisolated private static let loremIpsumParagraphVerseRanges: [ClosedRange<Int>] = {
        var nextVerse = 1

        return loremIpsumVerses.map { paragraphVerses in
            let range = nextVerse...(nextVerse + paragraphVerses.count - 1)
            nextVerse += paragraphVerses.count
            return range
        }
    }()

    nonisolated private static let loremIpsumVerseCount = loremIpsumVerses.joined().count

    // MARK: Views

    /// Main view
    var body: some View {
        ZStack {
            backgroundPassage
                .ignoresSafeArea()
            branding
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
        // Safe area insets here = navigation bar + tab bar; the background passage
        // ignores them, so its coordinates start at the top of the screen
        .onGeometryChange(for: PassageViewport.self) { proxy in
            let insets = proxy.safeAreaInsets
            return PassageViewport(height: insets.top + proxy.size.height + insets.bottom,
                                   visibleRange: insets.top...(insets.top + proxy.size.height))
        } action: { newViewport in
            viewport = newViewport
        }
        .task {
            await runBackgroundAnimation()
        }
        .task {
            await runPassageRecycler()
        }
    }

    private var branding: some View {
        VStack(spacing: 16) {
            // App icon + title + version
            horizontalBrandingAndVersion

            // Author + subtext
            VStack {
                Text("\(createdVerb) by Brandon Thomas")
                Text("Christ is King  ✝\u{FE0E}")
            }
            .font(.system(.callout, weight: .regular))
        }
        .shadow(color: Color(.tertiarySystemBackground), radius: 25)
    }

    /// Decorative Lorem Ipsum passage drawn with the reader's text pipeline
    /// (PassageTextRenderer + VerseHighlightRenderer), slowly scrolling, blurred behind branding
    private var backgroundPassage: some View {
        // Built once per body evaluation; the TimelineView below only moves it each frame
        let paragraphsView = passageParagraphs

        return TimelineView(.animation(paused: reduceMotion)) { context in
            Color.clear
                .overlay(alignment: .top) {
                    paragraphsView
                        .offset(y: -scrollOffset(at: context.date))
                }
        }
        .clipped()
        .allowsHitTesting(false)
        .blur(radius: 8)
        .opacity(backgroundOpacity)
        .overlay {
            ZStack {
                EmptyView()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemBackground).opacity(0.5))
        }
        .accessibilityHidden(true)
    }

    private var passageParagraphs: some View {
        VStack(spacing: 0) {
            ForEach(paragraphs) { paragraph in
                PassageTextRenderer.text(for: paragraph.runs,
                                         footnoteMarkerMode: .hidden,
                                         produceLinkAttributes: false) // decorative; no taps
                    .textRenderer(VerseHighlightRenderer(
                        settledVerses: nil,
                        revealingVerses: revealingVerses,
                        fadingVerses: fadingVerses,
                        tapOrigin: nil,
                        progress: revealProgress,
                        fadeProgress: fadeProgress,
                        persistedHighlights: [:]))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    // spacing lives in padding (not VStack spacing) so measured heights include it
                    .padding(EdgeInsets(top: 2, leading: 24, bottom: 10, trailing: 24))
                    .onGeometryChange(for: CGFloat.self) { proxy in
                        proxy.size.height
                    } action: { height in
                        paragraphHeights[paragraph.id] = height
                    }
            }
        }
        .font(.system(.body, design: .serif))
        .lineHeight(AttributedString.LineHeight.exact(points: passageLineHeight))
        .fixedSize(horizontal: false, vertical: true)
    }

    private var horizontalBrandingAndVersion: some View {
        HStack(spacing: 16) {
            // App Icon
            Image(.aboutIcon)
                .resizable()
                .frame(width: imageSize72, height: imageSize72)
                .clipShape(.rect)

            // App Title + Version
            VStack(alignment: .leading) {
                // App Title
                Text("Bible")
                    .font(.system(.title, weight: .medium))

                // Version
                if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
                   let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
                    Text("v\(version) (\(build))")
                        .font(.callout)
                }
            }
        }
    }

    // MARK: Functions (Private, Highlights)

    /// Fade the background passage in, then select + deselect random verse ranges every ~4s
    ///
    /// Runs until .task cancels it (view disappears); Task.sleep throws on cancellation
    private func runBackgroundAnimation() async {
        do {
            try await Task.sleep(for: .milliseconds(200))
            withAnimation(.bouncy(duration: 0.7)) {
                backgroundOpacity = 1
            }

            guard !reduceMotion else { return }

            while true {
                try await Task.sleep(for: .seconds(1))
                guard let verses = randomVisibleVerseRange() else {
                    // nothing fully on screen; try again next cycle
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

    /// 1–3 consecutive verses from paragraphs fully between the navigation bar and tab bar,
    /// or nil if none are
    ///
    /// The top edge is pushed down by the distance the text scrolls during one selection,
    /// so a selected paragraph stays fully visible until it fades out
    private func randomVisibleVerseRange() -> ClosedRange<Int>? {
        let visibleTop = viewport.visibleRange.lowerBound + Self.scrollSpeed * Self.selectionLifetime
        let visibleBottom = viewport.visibleRange.upperBound

        var paragraphTop = -scrollOffset(at: .now)
        var visibleRanges: [ClosedRange<Int>] = []

        for paragraph in paragraphs {
            guard let height = paragraphHeights[paragraph.id] else { break }

            if paragraphTop >= visibleTop && paragraphTop + height <= visibleBottom {
                visibleRanges.append(paragraph.verseRange)
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

    /// Distance from the top of the first laid-out paragraph to the top of the screen
    private func scrollOffset(at date: Date) -> CGFloat {
        let elapsed = reduceMotion ? 0 : CGFloat(date.timeIntervalSince(scrollStartDate))
        return Self.initialScrollOffset + Self.scrollSpeed * elapsed - removedHeight
    }

    /// Recycle paragraphs twice a second until .task cancels it
    private func runPassageRecycler() async {
        do {
            while true {
                recyclePassageParagraphs()
                try await Task.sleep(for: .milliseconds(500))
            }
        } catch {
            // cancelled; nothing to clean up
        }
    }

    /// Remove paragraphs scrolled fully above the screen; append one when the
    /// bottom of the passage gets close to the bottom of the screen
    private func recyclePassageParagraphs() {
        guard viewport.height > 0 else { return }

        var offset = scrollOffset(at: .now)

        // Remove from top. removedHeight grows by the same amount in the same update,
        // so the remaining paragraphs stay where they are on screen
        while paragraphs.count > 1,
              let first = paragraphs.first,
              let height = paragraphHeights[first.id],
              height + Self.recycleMargin < offset {
            paragraphs.removeFirst()
            paragraphHeights[first.id] = nil
            removedHeight += height
            offset -= height
        }

        // Append to bottom; wait until every paragraph has been measured
        let heights = paragraphs.compactMap { paragraphHeights[$0.id] }
        guard heights.count == paragraphs.count,
              let lastParagraph = paragraphs.last else { return }

        let contentHeight = heights.reduce(0, +)
        if contentHeight - offset < viewport.height + Self.recycleMargin {
            paragraphs.append(Self.backgroundParagraph(id: lastParagraph.id + 1))
        }
    }

    /// Build background paragraph `id`: cycles through loremIpsumVerses with verse numbers
    /// that keep increasing, so every laid-out verse number is unique for highlighting
    nonisolated private static func backgroundParagraph(id: Int) -> BackgroundParagraph {
        let sourceIndex = id % loremIpsumVerses.count
        let cycle = id / loremIpsumVerses.count
        let firstVerse = cycle * loremIpsumVerseCount + loremIpsumParagraphVerseRanges[sourceIndex].lowerBound
        let verses = loremIpsumVerses[sourceIndex]

        let runs = verses.enumerated().flatMap { index, verseText -> [RenderedPassageRun] in
            let verseNumber = firstVerse + index
            let verseRange = RenderedVerseRange(startVerse: verseNumber)
            return [.verseLabel(displayText: "\(verseNumber)", verseRange: verseRange),
                    .text(verseText, verseRange: verseRange)]
        }

        return BackgroundParagraph(id: id,
                                   runs: runs,
                                   verseRange: firstVerse...(firstVerse + verses.count - 1))
    }

    /// Loads the primary app icon using the file name Xcode writes into Info.plist.
    private static var appIcon: UIImage? {
        guard let icons = Bundle.main.infoDictionary?["CFBundleIcons"] as? [String: Any],
              let primary = icons["CFBundlePrimaryIcon"] as? [String: Any],
              let files = primary["CFBundleIconFiles"] as? [String],
              let name = files.last else {
            return nil
        }
        return UIImage(named: name)
    }
}

#Preview {
    SettingsAboutView()
}
