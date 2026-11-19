import SwiftUI

struct ContentView: View {

    // MARK: Properties (Private)

    private enum CurrentTab {
        case read
        case saved
        case settings
        case search
    }
    /// What tab are we on right now?
    @State private var selectedTab: CurrentTab = .read

    /// Mirrors tab bar minimization, derived from the bottom accessory's placement
    @State private var isTabBarExpanded = true

    /// Home Screen quick action handoff from the scene delegate
    private let quickActionRouter = QuickActionRouter.shared

    // MARK: Properties (Private, Environment)

    /// Read appEnvironment.readerStore environment value from current view environment
    ///
    /// Don't need "\." here because this is a type-based lookup for an observable instance
    /// placed into the environment: .environment(readerStore))
    @Environment(ReaderStore.self) private var readerStore: ReaderStore

    /// Read appEnvironment.libraryStore environment value from current view environment
    @Environment(LibraryStore.self) private var libraryStore: LibraryStore

    /// What's our currently saved theme preference?
    @Environment(\.readerTheme) private var readerTheme: ReaderThemeResolved

    /// Observed for changeCount only; see .onChange below
    @Environment(\.libraryRepository) private var libraryRepository

    // MARK: Properties (Private, Reader AutoLock)

    /// local preference
    @AppStorage(PreferencesStore.disableReaderAutoLockKey) private var disableReaderAutoLockKey = false

    /// Is SwiftBible foregrounded?
    @Environment(\.scenePhase) private var scenePhase

    /// Auto-lock is suppressed only while actively reading with the preference on
    private var shouldDisableIdleTimer: Bool {
        disableReaderAutoLockKey && selectedTab == .read && scenePhase == .active
    }

    // MARK: Views

    /// Primary application body
    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Read", systemImage: "book", value: CurrentTab.read) {
                ReaderView()
                // TODO: Listen Mode (v1.1)
                // TODO: move to ViewModifier
                    //.listenModeButton(isTabBarExpanded: isTabBarExpanded)
            }
            Tab("Saved", systemImage: "bookmark", value: CurrentTab.saved) {
                LibraryView(onShowInReader: { selectedTab = .read })
            }
            Tab("Settings", systemImage: "switch.2", value: CurrentTab.settings) {
                SettingsView()
                    .font(.body)
            }
            Tab("Search", systemImage: "magnifyingglass", value: CurrentTab.search) {
                SearchView()
                    .font(.body)
            }
        }
        .font(readerTheme.font(.body))
        .tabBarMinimizeBehavior($selectedTab.wrappedValue == CurrentTab.read ? .onScrollDown : .never) // added in iOS 26
//        .tabViewSearchActivation(.searchTabSelection) // added in iOS 26
        // "isEnabled" param added in iOS 26.1
        .tabViewBottomAccessory(isEnabled: $selectedTab.wrappedValue == CurrentTab.read && readerStore.loadState != .loading) {
            Group {
                if readerStore.selectedVerses == nil {
                    PassagePickerView()
                } else {
                    VerseActionsView()
                }
            }
            .background(TabBarExpansionReader(isExpanded: $isTabBarExpanded))
        }
        // Load Library data -- added here alongside existing .task in LibraryView
        // to prevent flashing of abbreviations on initial Library view load
        .task {
            // First load all annotations
            libraryStore.load()

            // Load book names for each annotation
            await libraryStore.loadMissingBookMetadata()
        }
        // Home Screen quick action: switch tabs, then clear so the same action can fire again
        // initial: true covers cold launch, where the action is set before this view appears
        .onChange(of: quickActionRouter.pending, initial: true) { _, action in
            guard let action else { return }
            switch action {
            case .read: selectedTab = .read
            case .saved: selectedTab = .saved
            case .search: selectedTab = .search
            }
            quickActionRouter.pending = nil
        }
        // Any annotation save/delete from anywhere (Reader, Library, editor sheet) bumps
        // changeCount; reload the Reader's per-passage annotation state here, once, so writers
        // never need to notify the Reader themselves
        // Lives on the root view because it stays on screen while any tab is visible
        .onChange(of: libraryRepository.changeCount) {
            readerStore.refreshPassageHighlights()
            // reload LibraryStore as well (otherwise it will only reload when focused)
            libraryStore.load()
            Task {
                await libraryStore.loadMissingBookMetadata()
            }
        }
        // Reader Auto-Lock
        .onChange(of: shouldDisableIdleTimer, initial: true) { _, disabled in
            UIApplication.shared.isIdleTimerDisabled = disabled
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
