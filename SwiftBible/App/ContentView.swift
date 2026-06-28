import SwiftUI

struct ContentView: View {

    // MARK: Properties (Private)

    /// Read appEnvironment.store environment value from current view environment
    ///
    /// Don't need "\." here because this is a type-based lookup for an observable object
    /// placed into the environment: .environment(store))
    @Environment(ReaderStore.self) private var readerStore: ReaderStore

    @State private var selectedTab: CurrentTab = .read

    private enum CurrentTab {
        case read
        case saved
        case themes
        case search
    }

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
            Tab("Themes", systemImage: "paintbrush", value: CurrentTab.themes) {
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
            tabBarAccessory
        }
    }

    /// Tab bar accessory for Read view
    ///
    /// TODO: Populate via API
    var tabBarAccessory: some View {
        Menu {
            Menu {
                ForEach(readerStore.books) { book in
                    Menu(book.displayName) {
                        ForEach(book.chapters) { chapter in
                            Button(action: {}) {
                                Text(chapter.displayName)
                            }
                        }
                    }
                }
            } label: {
                Label("Books", systemImage: "book.pages")
            }

            Menu {
                ForEach(readerStore.translations) { translation in
                    Button(action: {}) {
                        Text(translation.title)
                        Text(translation.abbreviation)
                            .foregroundColor(.secondary)
                    }
                }
            } label: {
                Label("Translations", systemImage: "textformat") // alt: character.book.closed
            }
            .menuOrder(.fixed)
        } label: {
            Group {
                Text(
                    "\(readerStore.selectedBook?.displayName ?? "Select Book") \(readerStore.selectedChapter?.displayName ?? "")"
                )
                    .padding(EdgeInsets(top: 0, leading: 15, bottom: 0, trailing: 0))
                Text("\(readerStore.selectedTranslation?.abbreviation ?? "")")
                    .foregroundColor(.secondary)
                Spacer()
            }
            .font(.system(size: UIFontMetrics(forTextStyle: .body).scaledValue(for: 14),
                          weight: .medium,
                          design: .serif))
        }
        .foregroundStyle(.primary) // Automatically adapts to light/dark
        .menuOrder(.fixed)
    }
}

#Preview("Loaded") {
    let repository = FakeBibleRepository()
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

#Preview("Failed") {
    let repository = FakeBibleRepository(throwWhenLoadingTranslations: true)
    let readerStore = ReaderStore(repository: repository)

    ContentView()
        .environment(readerStore)
}
