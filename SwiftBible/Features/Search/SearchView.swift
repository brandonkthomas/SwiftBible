//
//  SearchView.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 6/27/26.
//

import SwiftUI

/// Search tab
struct SearchView: View {

    /// Focus state for search bar
    @FocusState var isSearchBarFocused: Bool

    // MARK: Properties (Private)

    /// What's our current search query?
    @State private var query: String = ""

    /// What's our current search scope setting?
    ///
    /// Overridden on view appear by PreferencesStore
    @State private var scope: SearchScope = .all

    /// Only allow applying scope from PreferencesStore once
    @State private var hasAppliedScope: Bool = false

    /// Which translation are we looking for?
    @State private var searchTranslationID: Translation.ID?

    /// Explicit search translation, else reader selection, else default translation, else first available
    private var effectiveTranslationID: Translation.ID? {
        if let searchTranslationID {
            return searchTranslationID
        }
        if let selectedID = readerStore.selectedTranslation?.id {
            return selectedID
        }
        let translations = readerStore.translations
        let defaultTranslation = translations.first(where: {
            $0.abbreviation == ReaderStore.defaultTranslationAbbreviation
        })
        return defaultTranslation?.id ?? translations.first?.id
    }

    /// Abbreviation of the effective translation, for the Bible section header
    private var effectiveTranslationAbbreviation: String? {
        readerStore.translations.first(where: { $0.id == effectiveTranslationID })?.abbreviation
    }

    // MARK: Properties (Proj Env, Private)

    /// Read appEnvironment.searchStore environment value from current view environment
    ///
    /// Don't need "\." here because this is a type-based lookup for an observable instance
    /// placed into the environment: .environment(searchStore))
    @Environment(SearchStore.self) private var searchStore: SearchStore

    /// Read appEnvironment.readerStore environment value from current view environment
    @Environment(ReaderStore.self) private var readerStore: ReaderStore

    /// Read appEnvironment.libraryStore environment value from current view environment
    @Environment(LibraryStore.self) private var libraryStore: LibraryStore

    /// Read appEnvironment.preferencesStore environment value from current view environment
    @Environment(PreferencesStore.self) private var preferencesStore: PreferencesStore

    /// Read appEnvironment.catalogStore environment value from current view environment
    @Environment(BibleCatalogStore.self) private var bibleCatalogStore: BibleCatalogStore

    // MARK: Views

    /// Main body
    var body: some View {
        @Bindable var prefStore = preferencesStore

        NavigationStack {
            // no input yet
            if searchStore.isIdle {
                ContentUnavailableView(
                    "Search",
                    systemImage: "magnifyingglass",
                    description: Text("Find phrases, verses, or annotations.")
                )
            } else {
                List {
                    // Bible
                    if scope == .all || scope == .bible {
                        Section {
                            switch searchStore.bibleState {
                            case .searching:
                                ProgressView()
                            case .results:
                                ForEach(searchStore.bibleResults) { result in
                                    Text(result.snippet ?? result.bookCode) // TODO: custom view
                                }
                            default:
                                if effectiveTranslationID == nil {
                                    ProgressView()
                                } else {
                                    EmptyView()
                                }
                            }
                        } header: {
                            if let effectiveTranslationAbbreviation {
                                Text("Bible · \(effectiveTranslationAbbreviation)")
                            } else {
                                Text("Bible")
                            }
                        }
                    }
                    // Annotations
                    if scope == .all || scope == .annotations {
                        Section("Annotations") {
                            ForEach(searchStore.annotationResults) { annotation in
                                // TODO: strong-highlight query match in text
                                let data = LibraryRowViewData(annotation: annotation,
                                                              bibleCatalogStore: bibleCatalogStore,
                                                              libraryStore: libraryStore)
                                LibraryRowReadOnlyView(data: data)
                                .task {
                                    // Required for annotation to load its associated passage
                                    // Prereq for rendering this card's verse
                                    // Will use cache rather than API, if possible
                                    await libraryStore.loadPassage(for: annotation)
                                }
                            }
                        }
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            Group {
                SearchBarView(
                    text: $query,
                    scope: $scope,
                    translations: bibleCatalogStore.translationsByTitle,
                    selectedTranslationID: Binding(
                        get: { effectiveTranslationID },
                        set: { selectSearchTranslation($0) }
                    ),
                    isFocused: $isSearchBarFocused,
                    onTextChange: { text in
                        searchStore.annotationSearchQuery = text
                    }, onTextSubmit: { text in
                        guard let effectiveTranslationID else {
                            return
                        }
                        // pin the translation at the first search so later Reader changes
                        // never change (or re-request) Search's results
                        if searchTranslationID == nil {
                            searchTranslationID = effectiveTranslationID
                        }
                        await searchStore.submitBibleSearch(text,
                                                            translationID: effectiveTranslationID)
                    }
                )
            }
            // match TabBarBottomAccessory as closely as possible
            .padding(.horizontal, isSearchBarFocused ? 12 : 20)
            .padding(.bottom, 8)
        }
        // set
        .onAppear {
            guard !hasAppliedScope else { return }
            scope = preferencesStore.defaultSearchScope
            hasAppliedScope = true
        }
        .navigationTitle("Search")
        .navigationBarHidden(true)
    }

    // MARK: Functions (Private)

    /// User picked a translation in the Filter menu
    ///
    /// Re-runs current search only when its results are in a different translation...
    /// dont waste API calls. Nothing else (Reader changes, picking the same
    /// translation again) can start a new request
    private func selectSearchTranslation(_ translationID: Translation.ID?) {
        searchTranslationID = translationID

        guard let translationID,
              searchStore.bibleState != .idle,
              searchStore.bibleSearchTranslationID != translationID,
              !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        Task {
            await searchStore.submitBibleSearch(query, translationID: translationID)
        }
    }
}

#Preview("SearchView") {
    SearchView()
        .previewEnvironment()
}

#Preview("ContentView") {
    ContentView()
        .previewEnvironment()
}
