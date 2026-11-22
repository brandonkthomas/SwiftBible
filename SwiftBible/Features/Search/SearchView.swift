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

    /// Result sections that are collapsed
    @State private var collapsedSections: Set<ResultSection> = []

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
                            if !collapsedSections.contains(.bible) {
                                Group {
                                    switch searchStore.bibleState {
                                    case .idle:
                                        if !query.isEmpty {
                                            Text("Press Enter to search.")
                                                .foregroundStyle(.secondary)
                                                .font(.footnote)
                                        } else if searchTranslationID == nil {
                                            ProgressView()
                                        }
                                    case .searching:
                                        ProgressView()
                                    case .results:
                                        ForEach(searchStore.bibleResults) { result in
                                            SearchResultRowView(result: result,
                                                                query: query)
                                            .listRowInsets(EdgeInsets(top: 8,
                                                                      leading: 16,
                                                                      bottom: 8,
                                                                      trailing: 16))
                                        }
                                    case .empty:
                                        Text("No Results")
                                            .foregroundStyle(.secondary)
                                            .font(.footnote)
                                    case .unsupported:
                                        if let searchTranslationID,
                                           let abbreviation = bibleCatalogStore.translation(for: searchTranslationID)?.abbreviation {
                                            Text("Search is unavailable for \(abbreviation).")
                                                .foregroundStyle(.secondary)
                                                .font(.footnote)
                                        } else {
                                            Text("Search is unavailable for the selected translation.")
                                                .foregroundStyle(.secondary)
                                                .font(.footnote)
                                        }
                                    case .offline:
                                        Text("Unable to load results. Please check your internet connection.")
                                            .foregroundStyle(.secondary)
                                            .font(.footnote)
                                    case .failed:
                                        Text("Unable to load results. Please try again.")
                                            .foregroundStyle(.secondary)
                                            .font(.footnote)
                                    }
                                }
                                .listRowSeparator(.hidden)
                            }
                        } header: {
                            if let effectiveTranslationAbbreviation {
                                sectionHeaderView(title: "Bible · \(effectiveTranslationAbbreviation)",
                                                  section: .bible)
                            } else {
                                sectionHeaderView(title: "Bible", section: .bible)
                            }
                        }
                    }
                    // Annotations
                    if scope == .all || scope == .annotations {
                        Section {
                            Group {
                                if searchStore.annotationResults.isEmpty {
                                    Text("No Results")
                                        .foregroundStyle(.secondary)
                                        .font(.footnote)
                                } else {
                                    if !collapsedSections.contains(.annotations) {
                                        ForEach(searchStore.annotationResults) { annotation in
                                            // TODO: strong-highlight query match in text
                                            let data = LibraryRowViewData(annotation: annotation,
                                                                          bibleCatalogStore: bibleCatalogStore,
                                                                          libraryStore: libraryStore)
                                            LibraryRowReadOnlyView(data: data)
                                                .listRowInsets(EdgeInsets(top: 8,
                                                                          leading: 16,
                                                                          bottom: 8,
                                                                          trailing: 16))
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
                            .listRowSeparator(.hidden) // not working???
                        } header: {
                            sectionHeaderView(title: "Annotations", section: .annotations)
                        }
                    }
                }
                .listStyle(.plain)
                // contentMargins, not padding: padding shrinks the List frame so rows stop above the tab bar
                .contentMargins(.bottom, 64, for: .scrollContent)
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

    /// Tappable section header; toggles the section's collapsed state
    private func sectionHeaderView(title: LocalizedStringKey, section: ResultSection) -> some View {
        let isCollapsed = collapsedSections.contains(section)

        return Button {
            withAnimation(.snappy(duration: 0.35)) {
                if isCollapsed {
                    collapsedSections.remove(section)
                } else {
                    collapsedSections.insert(section)
                }
            }
        } label: {
            HStack {
                Text(title)
                    .font(.system(.title3, weight: .semibold))
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(isCollapsed ? -90 : 0))
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
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

    // MARK: Types (Private)

    /// Collapsible result sections
    private enum ResultSection {
        case bible
        case annotations
    }
}

#Preview("SearchView") {
    let libraryRepository = InMemoryLibraryRepository()
    for annotation in [PreviewFixtures.sampleHighlightAnnotation,
                       PreviewFixtures.sampleNoteAnnotation,
                       PreviewFixtures.sampleTagsAnnotation] {
        try? libraryRepository.save(annotation)
    }

    let environment = PreviewEnvironment(libraryRepository: libraryRepository)
    environment.libraryStore.load()

    return SearchView()
        .previewEnvironment(environment)
}

#Preview("ContentView") {
    ContentView()
        .previewEnvironment()
}
