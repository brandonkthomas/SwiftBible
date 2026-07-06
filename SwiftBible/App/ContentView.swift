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

    // MARK: Views

    /// Primary application body
    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Read", systemImage: "book", value: CurrentTab.read) {
                ReaderView()
            }
            Tab("Saved", systemImage: "bookmark", value: CurrentTab.saved) {
                LibraryView()
            }
            Tab("Customize", systemImage: "switch.2", value: CurrentTab.themes) {
                SettingsView()
            }
            Tab(value: CurrentTab.search, role: .search) {
                SearchView()
            } label: {
                Image(systemName: "magnifyingglass")
            }
        }
        .font(.system(.body, design: .serif))
        .tabBarMinimizeBehavior(TabBarMinimizeBehavior.onScrollDown) // added in iOS 26
        .tabViewSearchActivation(.searchTabSelection) // added in iOS 26
        // "isEnabled" param added in iOS 26.1
        .tabViewBottomAccessory(isEnabled: $selectedTab.wrappedValue == CurrentTab.read) {
            if readerStore.selectedVerses == nil {
                PassagePickerView()
            } else {
                VerseActionsView()
            }
        }
        .animation(.easeInOut, value: readerStore.selectedVerses == nil)
    }
}

// MARK: Xcode Canvas Previews

#Preview("Loaded") {
    let repository = FakeBibleRepository()
    let readerStore = ReaderStore(repository: repository)

    ContentView()
        .environment(readerStore)
}

#Preview("Failed") {
    let repository = FakeBibleRepository(throwWhenLoadingTranslations: true)
    let readerStore = ReaderStore(repository: repository)

    ContentView()
        .environment(readerStore)
}

#Preview("No Translations") {
    let repository = FakeBibleRepository(translations: [])
    let readerStore = ReaderStore(repository: repository)

    ContentView()
        .environment(readerStore)
}

#Preview("No Books") {
    let repository = FakeBibleRepository(books: [])
    let readerStore = ReaderStore(repository: repository)

    ContentView()
        .environment(readerStore)
}

#Preview("No Chapters") {
    let repository = FakeBibleRepository(books: FakeBibleRepository.booksWithoutChapters)
    let readerStore = ReaderStore(repository: repository)

    ContentView()
        .environment(readerStore)
}

#Preview("Loading") {
    let repository = FakeBibleRepository(forceLoadingState: true)
    let readerStore = ReaderStore(repository: repository)

    ContentView()
        .environment(readerStore)
}
