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
                        Section("Bible") {
                            ForEach(searchStore.bibleResults) { result in
                                Text(result.snippet ?? result.bookCode) // TODO: custom view
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
                    isFocused: $isSearchBarFocused,
                    onTextChange: { text in
                        searchStore.annotationSearchQuery = text
                    }, onTextSubmit: { text in
                        guard let selectedTranslation = readerStore.selectedTranslation else {
                            return
                        }
                        await searchStore.submitBibleSearch(text,
                                                            translationID: selectedTranslation.id)
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
}

#Preview("SearchView") {
    SearchView()
        .previewEnvironment()
}

#Preview("ContentView") {
    ContentView()
        .previewEnvironment()
}
