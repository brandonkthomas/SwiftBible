//
//  ReaderPassageView.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 6/27/26.
//

import SwiftUI

/// Main scrollview for text; only called once we've validated all other states
struct ReaderPassageView: View {

    // MARK: Properties

    /// Entire pre-rendered passage that we need to display
    /// Contains all paragraphs (text/labels/footnote markers) & actual footnote content
    var renderedPassage: RenderedPassage

    // MARK: Properties (System Env, Private)

    /// Is the tab bar accessory currently collapsed or expanded?
    @Environment(\.tabViewBottomAccessoryPlacement) private var placement

    // MARK: Properties (Proj Env, Private)

    /// Read appEnvironment.readerStore environment value from current view environment
    ///
    /// Don't need "\." here because this is a type-based lookup for an observable instance
    /// placed into the environment: .environment(readerStore))
    @Environment(ReaderStore.self) private var readerStore: ReaderStore

    // MARK: Properties (Footnotes, Private)

    /// When set, ReaderPassageFootnoteSheetView will open
    @State private var selectedVerseRangeForFootnote: RenderedVerseRange?

    // MARK: Properties (Verse Selection, Private)

    /// Used for reveal effects on verse highlight renders
    @State private var revealProgress: CGFloat = 0

    /// Used for fade-out effects on verse highlight renders
    @State private var fadeProgress: CGFloat = 1

    /// Used for tap animation calculation effects on verse highlight renders
    @State private var tapLocation: CGPoint?

    /// Used for tap animation calculation effects on verse highlight renders
    @State private var tappedParagraphIndex: Int?

    /// Keep track of which verses are already selected (so highlight add renderer can paint deltas)
    @State private var settledVerses: ClosedRange<Int>?

    /// Keep track of which verses are being actively selected (so highlight add renderer can paint deltas)
    @State private var revealingVerses: ClosedRange<Int>?

    /// Keep track of which verses are being deselected (so highlight remove renderer can paint deltas)
    @State private var fadingVerses: ClosedRange<Int>?

    // MARK: Views

    /// Reader view
    var body: some View {
        // TODO: add edge swipe custom animation for prev/next chapters
        ScrollView {
            // LazyVStack only renders components when they're visible BUT it makes scrollbar jumpy
            VStack {
                Group {
                    let paragraphs = renderedPassage.paragraphs

                    // all integer indexes (0-based); stop before paragraphs.count
                    //
                    // TODO: .verseLabel and .footnoteMarker runs increase line height
                    // (should stay consistent across all lines regardless of content)
                    ForEach(0..<paragraphs.count, id: \.self) { paragraphIndex in
                        // where did we last tap?
                        // only the tapped paragraph gets index; others get fallback origin rect calculation
                        let origin = tappedParagraphIndex == paragraphIndex ? tapLocation : nil

                        // build this paragraph into a Text view
                        PassageTextRenderer.text(for: paragraphs[paragraphIndex].runs,
                                                 mode: .collapsed)
                            // custom leading padding for inline/block quote styles
                            .padding(.leading,
                                     leadingPadding(for: paragraphs[paragraphIndex].style))
                            // custom TextRenderer to support verse highlights w/ animations
                            .textRenderer(VerseHighlightRenderer(
                                settledVerses: settledVerses,
                                revealingVerses: revealingVerses,
                                fadingVerses: fadingVerses,
                                tapOrigin: origin,
                                progress: revealProgress,
                                fadeProgress: fadeProgress,
                                persistedHighlights: readerStore.passageHighlightColors))
                            // record tap gestures for use with VerseHighlightRenderer
                            .simultaneousGesture(SpatialTapGesture(coordinateSpace: .local)
                                .onEnded {
                                    value in tapLocation = value.location
                                    tappedParagraphIndex = paragraphIndex
                                }
                            )
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineHeight(AttributedString.LineHeight.exact(points: 30))
                // inset on L/R edges; spacing between paragraphs
                .padding(EdgeInsets(top: 2, leading: 24, bottom: 2, trailing: 24))
            }
            .scrollTargetLayout()
            // prevent tab bar from covering up bottom few lines (HACK)
            // TODO: resolve properly? currently buggy when scrolling down hard to force-reveal tabbar
            .padding(EdgeInsets(top: 24, leading: 0, bottom: 75, trailing: 0))
        }
        // Bind footnote tap to set selectedVerse
        // Bind verse tap to selection/store/animations
        .environment(\.openURL, OpenURLAction { url in
            guard url.scheme == "swiftbible" else {
                return .systemAction // we dont want to handle anything else
            }

            // validation
            guard let components = URLComponents(string: url.absoluteString),
                  let queryItems = components.queryItems,
                  let startVerse = Int(queryItems.first(where: { $0.name == "sv" })?.value ?? "") else {
                return .discarded
            }

            // Footnote branch
            if url.host == "footnote" {
                let endVerse = Int(queryItems.first(where: { $0.name == "ev" })?.value ?? "")

                // setting this will open ReaderPassageFootnoteSheetView using the .sheet
                // modifier below
                selectedVerseRangeForFootnote = RenderedVerseRange(startVerse: startVerse,
                                                                   endVerse: endVerse)

                return .handled // we dealt with it; don't open a browser

            // Verse branch
            } else if url.host == "verse" {
                // calculate selection delta, update store selection state, do animation
                handleVerseSelection(components: components,
                                     queryItems: queryItems,
                                     startVerse: startVerse)

                return .handled // we dealt with it; don't open a browser

            // All other items: we don't need to handle; exit
            } else {
                return .discarded
            }
        })
        // Open ReaderPassageFootnoteSheetView when our OpenURLAction handler sets selectedVerse
        .sheet(item: $selectedVerseRangeForFootnote) { verse in
            ReaderPassageFootnoteSheetView(verseRange: verse,
                                           passage: renderedPassage)
                .presentationDetents([.medium, .large])
                .presentationContentInteraction(.automatic)
        }
        // Handle deselection animations/etc ONCE (applies to all callers across all views)
        .onChange(of: readerStore.selectedVerses) {
            if readerStore.selectedVerses == nil {
                fadeOutVerses(currentlyHighlightedVerses)
            }
        }
        // trigger slight tap on selection change
        .sensoryFeedback(.selection, trigger: readerStore.selectedVerses)
    }

    // MARK: Functions (Private)

    /// Handle updating verse tap selection in store + calculating delta + animating text
    private func handleVerseSelection(components: URLComponents,
                                      queryItems: [URLQueryItem],
                                      startVerse: Int) {
        // start verse / end verse ...
        // tapped verse's upper bound can be defined as "ev ?? sv"
        let endVerse = Int(queryItems.first(where: { $0.name == "ev" })?.value ?? "")

        // Snapshot what's already fully highlighted BEFORE we change anything.
        // Anything that may be mid-reveal becomes settled (fully animated) instantly so that
        //   it stays put and progress = 0 can't hide/flash it mid-animation
        //   (progress only affects revealing set)
        let previous = readerStore.selectedVerses
        settledVerses = previous

        // #1: update logical selection FIRST so we can read the result
        // Animated on its own so the tab bar accessory reacts
        withAnimation(.snappy(duration: 0.35)) {
            readerStore.handleVerseSelection(startVerse: startVerse,
                                             endVerse: endVerse)
        }

        // #2: now "new" is the post-change selection
        let new = readerStore.selectedVerses

        if let new {
            // Extend/fresh = the new range fully contains the old one (or there was none).
            let isExtend: Bool

            // require new to be strictly bigger than old
            if let previous {
                isExtend = new != previous
                    && new.lowerBound <= previous.lowerBound
                    && new.upperBound >= previous.upperBound
            } else {
                isExtend = true
            }

            if isExtend {
                // delta is only the newly grown side
                let delta: ClosedRange<Int>
                if let previous {
                    if new.lowerBound < previous.lowerBound {
                        delta = new.lowerBound...(previous.lowerBound - 1)
                    } else {
                        delta = (previous.upperBound + 1)...new.upperBound
                    }
                } else {
                    delta = new
                }

                // #3: tell the renderer WHAT to reveal, reset progress, THEN animate it
                // Renderer's draw() runs every frame while progress moves 0 to 1
                revealingVerses = delta
                revealProgress = 0
                withAnimation(.snappy(duration: 0.35)) {
                    revealProgress = 1
                }
            } else {
                // Shrink/isolate: no reveal, just settle smaller range
                fadeOutVerses(previous,
                              keeping: new)
            }
        } else {
            // Deselection: clear everything
            fadeOutVerses(previous)
        }
    }

    /// what range is currently visible as highlighted?
    private var currentlyHighlightedVerses: ClosedRange<Int>? {
        let settledVerses = self.settledVerses
        let revealingVerses = self.revealingVerses

        if let settledVerses, let revealingVerses {
            let lowerBound = min(settledVerses.lowerBound, revealingVerses.lowerBound)
            let upperBound = max(settledVerses.upperBound, revealingVerses.upperBound)
            return lowerBound...upperBound
        } else {
            return settledVerses ?? revealingVerses
        }
    }

    /// Does this paragraph style require leading padding?
    private func leadingPadding(for style: RenderedParagraphStyle) -> CGFloat {
        switch style {
        case .paragraph:
            return 0
        case .quoteLine:
            return 18
        case .indentedLine:
            return 36
        }
    }

    /// handles deselection of all current/animating/animated verse selections
    private func fadeOutVerses(_ verses: ClosedRange<Int>?,
                               keeping remainingVerses: ClosedRange<Int>? = nil) {
        guard let verses else {
            return
        }

        fadingVerses = verses
        settledVerses = remainingVerses
        revealingVerses = nil

        fadeProgress = 1

        withAnimation(.snappy(duration: 0.35)) {
            fadeProgress = 0
        } completion: {
            fadingVerses = nil
        }
    }
}

// MARK: Xcode Canvas Previews

#Preview {
    let repository = FakeBibleRepository()

    let readerStore = ReaderStore(repository: repository,
                                  libraryRepository: PreviewFixtures.seededLibraryRepository())

    // Drive the real load path so passageHighlightColors is populated exactly as
    // it is at runtime — no ReaderStore preview-only surface required.
    ReaderPassagePreviewHost(readerStore: readerStore)
}

/// Preview-only host: drives ReaderStore through its public load lifecycle, then
/// renders ReaderPassageView from the store's own rendered passage.
private struct ReaderPassagePreviewHost: View {
    let readerStore: ReaderStore

    var body: some View {
        Group {
            if let renderedPassage = readerStore.selectedRenderedPassage {
                ReaderPassageView(renderedPassage: renderedPassage)
            } else {
                ProgressView()
            }
        }
        .environment(readerStore)
        .task {
            await readerStore.loadTranslationsAndBooks()
            await readerStore.loadSelectedPassage()
        }
    }
}
