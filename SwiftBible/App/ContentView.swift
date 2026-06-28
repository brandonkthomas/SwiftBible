import SwiftUI

struct ContentView: View {

    // MARK: Properties (Private)

    /// Read appEnvironment.store environment value from current view environment
    ///
    /// Don't need "\." here because this is a type-based lookup for an observable instance
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
            tabBarAccessory
        }
    }

    /// Tab bar accessory for Read view
    ///
    /// TODO: move to own file...?
    var tabBarAccessory: some View {
        Menu {
            // Books + Chapters nested menus
            Menu {
                ForEach(readerStore.books) { book in
                    Menu(book.displayName) {
                        ForEach(book.chapters) { chapter in
                            Button(action: {
                                readerStore.selectBookAndChapter(bookID: book.id,
                                                                 chapterID: chapter.id)
                            }) {
                                Text(chapter.displayName)
                            }
                        }
                    }
                }
            } label: {
                Label("Books", systemImage: "books.vertical")
            }
            .menuOrder(.fixed)

            // Translations menu
            Menu {
                ForEach(readerStore.translations) { translation in
                    Button(action: {
                        Task {
                            await readerStore.selectTranslationAndReloadBooks(id: translation.id)
                        }
                    }) {
                        Text(translation.title)
                        Text(translation.abbreviation)
                            .foregroundColor(.secondary)
                    }
                }
            } label: {
                Label("Translations", systemImage: "text.redaction")
            }
            .menuOrder(.fixed)
        } label: {
            // Label: selected Book/Chapter names & Translation abbreviation
            Group {
                // Show corresponding View to current loadState
                // This will automatically refresh when we change @Observable loadState
                switch readerStore.loadState {
                // no translations should never happen
                case .emptyTranslations,
                     .failed(_):
                    Text("Content Unavailable")
                default:
                    tabBarAccessoryDefaultView
                }
            }
//            .frame(alignment: .leading) // TODO: not working; may just keep centered
            .font(.system(size: UIFontMetrics(forTextStyle: .body).scaledValue(for: 14),
                          weight: .medium,
                          design: .serif))
        }
        .foregroundStyle(.primary) // Automatically adapts to light/dark
        .menuOrder(.fixed)
    }

    private var tabBarAccessoryDefaultView: some View {
        Group {
            Text(
                "\(readerStore.selectedBook?.displayName ?? "Select Book") \(readerStore.selectedChapter?.displayName ?? "")"
            )
//                .padding(EdgeInsets(top: 0, leading: 15, bottom: 0, trailing: 0))
            Text("\(readerStore.selectedTranslation?.abbreviation ?? "")")
                .foregroundColor(.secondary)
        }
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

#Preview("No Books") { // TODO: this case needs tabBarAccessory to read "Select Translation"
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
