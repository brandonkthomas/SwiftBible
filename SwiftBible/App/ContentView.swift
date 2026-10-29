import SwiftUI

struct ContentView: View {

    // MARK: Properties (Private)

    @State private var selectedTab: CurrentTab = .read

    private enum CurrentTab {
        case read
        case saved
        case themes
        case search
    }

    /// Read appEnvironment.readerStore environment value from current view environment
    ///
    /// Don't need "\." here because this is a type-based lookup for an observable instance
    /// placed into the environment: .environment(readerStore))
    @Environment(ReaderStore.self) private var readerStore: ReaderStore

    /// Read appEnvironment.libraryStore environment value from current view environment
    @Environment(LibraryStore.self) private var libraryStore: LibraryStore

    // MARK: Views

    /// Primary application body
    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Read", systemImage: "book", value: CurrentTab.read) {
                ReaderView()
            }
            Tab("Saved", systemImage: "bookmark", value: CurrentTab.saved) {
                LibraryView(onShowInReader: { selectedTab = .read })
            }
            Tab("Customize", systemImage: "switch.2", value: CurrentTab.themes) {
                SettingsView()
            }
            Tab("Search", systemImage: "magnifyingglass", value: CurrentTab.search) {
                SearchView()
            }
        }
        .font(.system(.body, design: .serif))
        .tabBarMinimizeBehavior(.onScrollDown) // added in iOS 26
        .tabViewSearchActivation(.searchTabSelection) // added in iOS 26
        // "isEnabled" param added in iOS 26.1
        .tabViewBottomAccessory(isEnabled: $selectedTab.wrappedValue == CurrentTab.read && readerStore.loadState != .loading) {
            if readerStore.selectedVerses == nil {
                PassagePickerView()
            } else {
                VerseActionsView()
            }
        }
        // Load Library data -- added here alongside existing .task in LibraryView
        // to prevent flashing of abbreviations on initial Library view load
        .task {
            // First load all annotations
            libraryStore.load()

            // Load book names for each annotation
            await libraryStore.loadMissingBookMetadata()
        }
    }
}

// MARK: Xcode Canvas Previews

#Preview("Loaded") {
    ContentView()
        .previewEnvironment(PreviewEnvironment(libraryRepository: PreviewFixtures.seededLibraryRepository()))
}

#Preview("Failed") {
    ContentView()
        .previewEnvironment(PreviewEnvironment(repository: FakeBibleRepository(throwWhenLoadingTranslations: true)))
}

#Preview("No Translations") {
    ContentView()
        .previewEnvironment(PreviewEnvironment(repository: FakeBibleRepository(translations: [])))
}

#Preview("No Books") {
    ContentView()
        .previewEnvironment(PreviewEnvironment(repository: FakeBibleRepository(books: [])))
}

#Preview("No Chapters") {
    ContentView()
        .previewEnvironment(PreviewEnvironment(repository: FakeBibleRepository(books: FakeBibleRepository.booksWithoutChapters)))
}

#Preview("Loading") {
    ContentView()
        .previewEnvironment(PreviewEnvironment(repository: FakeBibleRepository(forceLoadingState: true)))
}
