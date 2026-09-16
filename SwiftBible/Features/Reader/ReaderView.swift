//
//  ReaderView.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 6/27/26.
//

import SwiftUI

/// TODO: Edge swipe for next/prev chapter
struct ReaderView: View {

    // MARK: Properties (Private)

    /// Read appEnvironment.readerStore environment value from current view environment
    ///
    /// Don't need "\." here because this is a type-based lookup for an observable instance
    /// placed into the environment: .environment(readerStore))
    @Environment(ReaderStore.self) private var readerStore: ReaderStore

    /// Calculated -- what is our current system theme?
    @Environment(\.colorScheme) private var colorScheme

    // MARK: Views

    /// Reader view
    var body: some View {
        ZStack {
            // TODO: Store user preference + fix font color to match
            // aka store font alongside theme background
            if colorScheme == .dark {
                AppTheme.themeOffBlack
                    .ignoresSafeArea()
            } else {
                AppTheme.themeOffWhite
                    .ignoresSafeArea()
            }

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
            case .failed(let message):
                ContentUnavailableView(
                    "Content Unavailable",
                    systemImage: "text.page.slash",
                    description: Text(message)
                )
            case .loaded:
                if readerStore.selectedReference == nil {
                    // we do NOT have a selected reference
                    passageUnavailableView
                } else {
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
                    case .failed(let message):
                        ContentUnavailableView(
                            "Content Unavailable",
                            systemImage: "text.page.slash",
                            description: Text(message)
                        )
                    case .loaded:
                        if let renderedPassage = readerStore.selectedRenderedPassage {
                            ReaderPassageView(renderedPassage: renderedPassage)
                        } else {
                            passageUnavailableView
                        }
                    }
                }
            }
        }
        // initial load
        .task {
            await readerStore.loadTranslationsAndBooks()
            await readerStore.loadSelectedPassage()
        }
        .navigationTitle(readerStore.selectedReferenceFriendlyName ?? "No Passage Selected")
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
    let repository = FakeBibleRepository()
    let passageStore = BiblePassageStore(repository: repository)
    let readerStore = ReaderStore(passageStore: passageStore,
                                  catalogStore: BibleCatalogStore(repository: repository),
                                  libraryRepository: PreviewFixtures.seededLibraryRepository())

    ReaderView()
        .environment(readerStore)
}

#Preview("Failed") {
    let repository = FakeBibleRepository(throwWhenLoadingTranslations: true)
    let passageStore = BiblePassageStore(repository: repository)
    let readerStore = ReaderStore(passageStore: passageStore,
                                  catalogStore: BibleCatalogStore(repository: repository),
                                  libraryRepository: InMemoryLibraryRepository())

    ReaderView()
        .environment(readerStore)
}

#Preview("No Translations") {
    let repository = FakeBibleRepository(translations: [])
    let passageStore = BiblePassageStore(repository: repository)
    let readerStore = ReaderStore(passageStore: passageStore,
                                  catalogStore: BibleCatalogStore(repository: repository),
                                  libraryRepository: InMemoryLibraryRepository())

    ReaderView()
        .environment(readerStore)
}

#Preview("No Books") {
    let repository = FakeBibleRepository(books: [])
    let passageStore = BiblePassageStore(repository: repository)
    let readerStore = ReaderStore(passageStore: passageStore,
                                  catalogStore: BibleCatalogStore(repository: repository),
                                  libraryRepository: InMemoryLibraryRepository())

    ReaderView()
        .environment(readerStore)
}

#Preview("No Chapters") {
    let repository = FakeBibleRepository(books: FakeBibleRepository.booksWithoutChapters)
    let passageStore = BiblePassageStore(repository: repository)
    let readerStore = ReaderStore(passageStore: passageStore,
                                  catalogStore: BibleCatalogStore(repository: repository),
                                  libraryRepository: InMemoryLibraryRepository())

    ReaderView()
        .environment(readerStore)
}

#Preview("Loading") {
    let repository = FakeBibleRepository(forceLoadingState: true)
    let passageStore = BiblePassageStore(repository: repository)
    let readerStore = ReaderStore(passageStore: passageStore,
                                  catalogStore: BibleCatalogStore(repository: repository),
                                  libraryRepository: InMemoryLibraryRepository())

    ReaderView()
        .environment(readerStore)
}
