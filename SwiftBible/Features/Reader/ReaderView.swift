//
//  ReaderView.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 6/27/26.
//

import SwiftUI
import TipKit

/// TODO: Edge swipe for next/prev chapter
struct ReaderView: View {

    // MARK: Properties (Private)

    /// Read appEnvironment.readerStore environment value from current view environment
    ///
    /// Don't need "\." here because this is a type-based lookup for an observable instance
    /// placed into the environment: .environment(readerStore))
    @Environment(ReaderStore.self) private var readerStore: ReaderStore

    /// What's our current configured theme?
    @Environment(\.readerTheme) private var readerTheme

    /// Tracked current TipKit Tip ID (for timer)
    @State private var shownTipID: String?

    @State private var lastShownTip: (any Tip)?

    // MARK: Views

    /// Reader view
    var body: some View {
        ZStack {
            // Background color
            readerTheme.backgroundColor
                .ignoresSafeArea() // keep extending under the safe areas

            // Show corresponding View to current loadState
            // This will automatically refresh when we change @Observable loadState
            switch readerStore.loadState {
            case .idle,
                 .loading:
                // TODO: continue to show ReaderPassageView but blur+overlay ProgressView while we load new data
                ProgressView()
                    .controlSize(.large)
            case .emptyTranslations:
                // no translations should never happen
                ContentUnavailableView(
                    "Content Unavailable",
                    systemImage: "text.page.slash",
                    description: Text("An error occurred while loading Bibles.")
                )
            case .emptyBooks:
                ContentUnavailableView(
                    "Content Unavailable",
                    systemImage: "text.page.slash",
                    description: Text("The selected translation is unavailable.")
                )
            case .emptyChapters:
                ContentUnavailableView(
                    "Content Unavailable",
                    systemImage: "text.page.slash",
                    description: Text("The selected book is unavailable.")
                )
            case .offline:
                offlineView
            case .failed(let message):
                ContentUnavailableView(
                    "Content Unavailable",
                    systemImage: "text.page.slash",
                    description: Text(message)
                )
            case .loaded:
                if readerStore.selectedReference != nil {
                    // we have a selected reference
                    // Show corresponding View to current passageLoadState
                    // This will automatically refresh when we change @Observable passageLoadState
                    switch readerStore.passageLoadState {
                    case .idle:
                        ProgressView()
                            .controlSize(.large)
                    case .loading:
                        ProgressView()
                            .controlSize(.large)
                    case .offline:
                        offlineView
                    case .failed(let message):
                        ContentUnavailableView(
                            "Content Unavailable",
                            systemImage: "text.page.slash",
                            description: Text(message)
                        )
                    case .loaded:
                        if let renderedPassage = readerStore.selectedRenderedPassage {
                            ReaderPassageView(renderedPassage: renderedPassage)
                                .id(readerStore.selectedReference)
                        } else {
                            passageUnavailableView
                        }
                    }
                } else {
                    // we do NOT have a selected reference
                    passageUnavailableView
                }
            }
        }
        // Onboarding tips float above the passage picker (tab bar accessory)
        // On the ZStack, not inside ReaderPassageView's ScrollView
        // .popoverTip() requires one tap to dismiss + eats touch input on entire bg
        // Ordered group shows 1 tip at a time; any tip that isn't current is nil and
        //   its TipView draws nothing
        .overlay(alignment: .bottom) {
            if readerStore.loadState == .loaded {
                VStack(spacing: 0) {
                    if shownTipID != nil && shownTipID == ReaderTips.onboarding.currentTip?.id {
                        Group {
                            // only while the picker is in the accessory; a verse selection swaps in
                            // VerseActionsView, and the arrow would point at that instead
                            if readerStore.selectedVerses == nil {
                                TipView(ReaderTips.onboarding.currentTip as? PassagePickerTip,
                                        arrowEdge: .none)
                            }
                            TipView(ReaderTips.onboarding.currentTip as? VerseSelectionTip)
                            if readerStore.selectedVerses != nil {
                                TipView(ReaderTips.onboarding.currentTip as? VerseActionsTip)
                            }
                            TipView(ReaderTips.onboarding.currentTip as? EdgeSwipeTip)
                        }
                        .tipBackground(Color.clear)
                        .glassEffect(.regular.interactive(),
                                     in: .rect(cornerRadius: 28))
                    }
                }
                .padding(.horizontal, CGFloat(readerTheme.marginPoints))
                .padding(.bottom, 8)
                .task(id: ReaderTips.onboarding.currentTip?.id) {
                    // check last tip's resolution
                    var lastShownTipClosedManually: Bool = false
                    if case .invalidated(.tipClosed) = lastShownTip?.status {
                        lastShownTipClosedManually = true
                    }
                    // clear
                    withAnimation(.snappy) {
                        shownTipID = nil
                    }
                    // wait if tip was resolved thru regular flow
                    if !lastShownTipClosedManually {
                        try? await Task.sleep(for: .seconds(1.5))
                    }
                    // show new tip
                    withAnimation(.snappy) {
                        let currentTip = ReaderTips.onboarding.currentTip
                        shownTipID = currentTip?.id
                        lastShownTip = currentTip
                    }
                }
            }
        }
        // initial load
        .task {
            await readerStore.loadTranslationsAndBooks()
            await readerStore.loadSelectedPassage()
        }
        .navigationTitle(readerStore.selectedReferenceFriendlyName ?? String(localized: "No Passage Selected", comment: "Reader navigation short title shown when no passage is selected"))
        .chapterEdgeSwipe(canGoPrevious: readerStore.loadState == .loaded
                          && readerStore.previousAdjacentChapterExists,
                          canGoNext: readerStore.loadState == .loaded
                          && readerStore.nextAdjacentChapterExists,
                          onCommit: { direction in
            await readerStore.selectAdjacentChapter(direction)
        })
    }

    /// No connection; ContentView reloads thru ReaderStore when our network returns
    var offlineView: some View {
        ContentUnavailableView(
            "No Internet Connection",
            systemImage: "wifi.slash",
            description: Text("Connect to the Internet to read passages.")
        )
    }

    /// Selected Passage is unavailable / doesnt exist
    var passageUnavailableView: some View {
        ContentUnavailableView {
            Label {
                Text("No Passage Selected")
            } icon: {
                Image(systemName: "rectangle.dashed")
                    .rotationEffect(.degrees(90)) // Rotate only the image
            }
        } description: {
            Text("Select a passage using the picker below.")
        }
    }
}

// MARK: Xcode Canvas Previews

#Preview("Loaded") {
    ReaderView()
        .previewEnvironment(PreviewEnvironment(libraryRepository: PreviewFixtures.seededLibraryRepository()))
}

#Preview("Failed") {
    ReaderView()
        .previewEnvironment(PreviewEnvironment(repository: FakeBibleRepository(throwWhenLoadingTranslations: true)))
}

#Preview("No Translations") {
    ReaderView()
        .previewEnvironment(PreviewEnvironment(repository: FakeBibleRepository(translations: [])))
}

#Preview("No Books") {
    ReaderView()
        .previewEnvironment(PreviewEnvironment(repository: FakeBibleRepository(books: [])))
}

#Preview("No Chapters") {
    ReaderView()
        .previewEnvironment(PreviewEnvironment(repository: FakeBibleRepository(books: FakeBibleRepository.booksWithoutChapters)))
}

#Preview("Loading") {
    ReaderView()
        .previewEnvironment(PreviewEnvironment(repository: FakeBibleRepository(forceLoadingState: true)))
}
