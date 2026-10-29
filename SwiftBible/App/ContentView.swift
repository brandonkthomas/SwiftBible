import SwiftUI

struct ContentView: View {

    // MARK: Properties (Private)

    @State private var selectedTab: CurrentTab = .read

    /// Mirrors tab bar minimization, derived from the bottom accessory's placement
    @State private var isTabBarExpanded = true

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
                // TODO: Listen Mode (v1.1)
//                    .safeAreaInset(edge: .bottom, alignment: .trailing, spacing: nil) {
//                        if readerStore.loadState == .loaded {
//                            Button {
//                                // TODO: Listen Mode
//                                // Similar to accessibility feature "Speak Selection"
//                                // Auto-scroll and realtime word/line highlight
//                                // Show small sheet w/ play/pause, pacing, auto-advance chapter, voice
//                                // Allow disabling in Settings > Reader > Show Listen Mode
//                            } label: {
//                                Image(systemName: "waveform")
//                                    .frame(width: 24, height: 24)
//                                    .imageScale(.large)
//                                    .foregroundStyle(Color.primary)
//                                    .padding(10)
//                            }
//                            .glassEffect(.regular.interactive(), in: .circle)
//                            .safeAreaPadding(.trailing, 20)
//                            .safeAreaPadding(.bottom, 8)
//                            .opacity(isTabBarExpanded ? 1 : 0)
//                            .allowsHitTesting(isTabBarExpanded)
//                            .accessibilityHidden(!isTabBarExpanded)
//                            .animation(
//                                isTabBarExpanded
//                                ? .bouncy(duration: 0.3)
//                                : .bouncy(duration: 0.3),
//                                value: isTabBarExpanded
//                            )
//                        }
//                    }
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
    }
}

/// Reports whether the tab bar is expanded. SwiftUI has no direct tab bar minimized state,
/// but the bottom accessory's placement is `.inline` exactly when the tab bar is minimized.
/// Must be placed inside `tabViewBottomAccessory` content to receive the placement.
private struct TabBarExpansionReader: View {

    @Environment(\.tabViewBottomAccessoryPlacement) private var placement

    @Binding var isExpanded: Bool

    var body: some View {
        Color.clear
            .onChange(of: placement, initial: true) { _, newValue in
                isExpanded = newValue != .inline
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
