//
//  SearchView.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 6/27/26.
//

import SwiftUI

/// Search tab
struct SearchView: View {

    /// Called after the reader has been pointed at a result's passage
    var onShowInReader: () -> Void = {}

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

    /// Results scroll offset; reset to top when the results change
    @State private var scrollPosition = ScrollPosition(edge: .top)

    /// Did changing a specific annotation's highlight color fail?
    @State private var didHighlightColorChangeFail: Bool = false

    /// Did deleting a specific annotation fail?
    @State private var didDeleteFail: Bool = false

    /// AnnotationEditor session:
    /// if nil, nothing selected;
    /// if non-nil, we have an existing session and need to open AnnotationEditorSheetView
    @State private var annotationEditor: AnnotationEditor?

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
                // ScrollView + LazyVStack rather than List, same as LibraryView: List resizes rows
                //   around their center, so expanding/collapsing an annotation card jumped
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        // Bible
                        if scope == .all || scope == .bible {
                            Section {
                                if !collapsedSections.contains(.bible) {
                                    // Corrections
                                    if let bibleSearchedInsteadFor = searchStore.bibleSearchedInsteadFor {
                                        VStack(alignment: .leading, spacing: 5) {
                                            // this is the original typo
                                            Text("Showing corrected results")
                                                .font(.footnote)
                                            Button {
                                                Task {
                                                    // search the original words exactly; quotes don't
                                                    // stop YouVersion's correction, exactText does
                                                    await triggerSearch(for: bibleSearchedInsteadFor,
                                                                        applySuggestionCorrection: true,
                                                                        exactText: true)
                                                }
                                            } label: {
                                                Text("Search instead for “\(bibleSearchedInsteadFor)”?")
                                                    .foregroundStyle(.accent) // imply interactivity
                                                    .font(.footnote)
                                            }
                                        }
                                    }

                                    // Suggestions
                                    if !searchStore.bibleSuggestions.isEmpty {
                                        ForEach(searchStore.bibleSuggestions, id: \.self) { suggestion in
                                            Button {
                                                Task {
                                                    await triggerSearch(for: suggestion,
                                                                        applySuggestionCorrection: true)
                                                }
                                            } label: {
                                                Text("Did you mean \"\(suggestion)\"?")
                                                    .foregroundStyle(.accent) // imply interactivity
                                                    .font(.footnote)
                                            }
                                        }
                                    }

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
                                            // All Bible results
                                            ForEach(searchStore.bibleResults) { result in
                                                SearchResultRowView(result: result,
                                                                    query: query,
                                                                    onPassageViewRequested: {
                                                    await showInReader(translationID: result.translationID,
                                                                       bookCode: result.bookCode,
                                                                       chapter: result.chapter)
                                                })
                                            }
                                            if searchStore.canLoadMoreBibleResults {
                                                loadMoreBibleResultsView
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
                                    if !collapsedSections.contains(.annotations) {
                                        if searchStore.annotationResults.isEmpty {
                                            Text("No Results")
                                                .foregroundStyle(.secondary)
                                                .font(.footnote)
                                        } else {
                                            ForEach(searchStore.annotationResults) { annotation in
                                                // TODO: strong-highlight query match in text
                                                annotationRowView(annotation: annotation)
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
                            } header: {
                                sectionHeaderView(title: "Annotations", section: .annotations)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
                // Scroll to top when results change (same fix as LibraryView: scrolled far down, a
                //   shorter LazyVStack left the ScrollView past its end, permanently blank)
                //   query: annotation results filter live while typing
                //   scope: hides a whole section
                //   bibleState: a new search replaces the Bible results
                .scrollPosition($scrollPosition)
                .onChange(of: query) {
                    scrollPosition.scrollTo(edge: .top)
                }
                .onChange(of: scope) {
                    scrollPosition.scrollTo(edge: .top)
                }
                .onChange(of: searchStore.bibleState) {
                    scrollPosition.scrollTo(edge: .top)
                }
                // contentMargins, not padding: padding shrinks the ScrollView frame so rows stop above the tab bar
                .contentMargins(.bottom, 64, for: .scrollContent)
                // Enables the rows' .swipeActions outside a List (iOS 27+)
                .swipeActionsContainerIfAvailable()
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
                        Task {
                            await triggerSearch(for: text)
                        }
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
        // Deletion failure popup
        .alert("Unable to Delete Annotation",
               isPresented: $didDeleteFail) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Please try again.")
        }
        // Highlight change failure popup
        .alert("Unable to Change Highlight Color",
               isPresented: $didHighlightColorChangeFail) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Please try again.")
        }
        // Fire AnnotationEditorSheetView when $annotationEditor instance is assigned
        .sheet(
            item: $annotationEditor,
            onDismiss: {
                withAnimation {
                    libraryStore.load()
                }
            },
            content: { editor in
                AnnotationEditorSheetView(editor: editor,
                                          bibleCatalogStore: bibleCatalogStore)
                .presentationDragIndicator(.visible)
            }
        )
    }

    /// Annotation result card with the same menu, context menu, and swipe actions as LibraryView
    ///
    /// Inside a List, .swipeActions works on every supported iOS version
    private func annotationRowView(annotation: VerseAnnotation) -> some View {
        let data = LibraryRowViewData(annotation: annotation,
                                      bibleCatalogStore: bibleCatalogStore,
                                      libraryStore: libraryStore)

        return LibraryRowView(
            data: data,
            isRowSelected: nil, // Search has no selection mode
            onHighlightColorChangeRequested: { color in
                let didChange = withAnimation(.snappy(duration: 0.35)) {
                    libraryStore.changeHighlightColor(annotation.id,
                                                      color: color)
                }
                didHighlightColorChangeFail = !didChange
            },
            onDeleteRequested: {
                let didDelete = withAnimation(.snappy(duration: 0.35)) {
                    libraryStore.delete(annotation.id)
                }
                didDeleteFail = !didDelete
            },
            onPassageViewRequested: {
                await showInReader(translationID: annotation.translationID,
                                   bookCode: annotation.bookCode,
                                   chapter: annotation.chapter)
            },
            onAnnotationEditorRequested: {
                annotationEditor = libraryStore.annotationEditor(for: annotation)
            },
            onRowSelected: {}
        )
    }

    /// Load More Results button, or a spinner while the next page loads
    @ViewBuilder
    private var loadMoreBibleResultsView: some View {
        if searchStore.isLoadingNextPage {
            ProgressView()
        } else {
            Button {
                Task {
                    await searchStore.loadNextBiblePage()
                }
            } label: {
                Text("Load More Results")
            }
            .padding(15)
            // Padding isn't part of hit area, so route taps on the whole rect to focus
            .contentShape(.rect(cornerRadius: .infinity))
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: .infinity))
            .frame(maxWidth: .infinity, alignment: .center)
        }
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

    /// Points the reader at a passage's chapter, then switches to the Read tab
    private func showInReader(translationID: Translation.ID,
                              bookCode: String,
                              chapter: Int) async {
        await readerStore.selectTranslationBookAndChapter(
            translationID: translationID,
            bookID: bookCode,
            chapterID: "\(bookCode).\(chapter)"
        )
        onShowInReader()
    }

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

    /// Search for a new query
    ///
    /// exactText: search the words as typed, without the provider's spelling correction
    private func triggerSearch(for query: String,
                               applySuggestionCorrection: Bool = false,
                               exactText: Bool = false) async {
        guard let effectiveTranslationID else {
            return
        }
        // pin the translation at the first search so later Reader changes
        // never change (or re-request) Search's results
        if searchTranslationID == nil {
            searchTranslationID = effectiveTranslationID
        }
        if applySuggestionCorrection {
            self.query = query
        }
        await searchStore.submitBibleSearch(query,
                                            translationID: effectiveTranslationID,
                                            exactText: exactText)
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
