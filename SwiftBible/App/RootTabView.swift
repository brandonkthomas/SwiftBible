import SwiftUI

struct RootTabView: View {

    // MARK: Properties (Private)

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
            ReaderView().tabBarAccessory
        }
    }
}

#Preview {
    RootTabView()
}
