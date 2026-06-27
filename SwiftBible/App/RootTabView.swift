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

    private var themeDefault: Color = .init(.systemBackground)
    private var themeOffBlack: Color = .init(red: 0.075, green: 0.075, blue: 0.075)
    private var themeBlack: Color = .init(.black)
    private var themeOffWhite: Color = .init(red: 0.925, green: 0.901, blue: 0.858)
    private var themeWhite: Color = .init(.white)

    private var demoText: String = "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Aliquam ac libero non ipsum convallis suscipit at a tortor. In ligula elit, rhoncus sit amet auctor id, ornare id purus. Nullam neque mauris, luctus euismod malesuada at, tempus et enim. Cras tempus efficitur mauris, non dapibus diam rutrum nec. Praesent sollicitudin massa et elementum efficitur. Interdum et malesuada fames ac ante ipsum primis in faucibus. Phasellus metus ipsum, pharetra sed urna et, facilisis maximus massa. Suspendisse potenti. Curabitur elementum tellus in nulla vulputate eleifend. Sed at pharetra nunc, sed tempus ligula. Vestibulum scelerisque ut enim vel malesuada. Mauris in est sem. Donec mollis dolor vitae mi gravida, eu feugiat est interdum. Sed eu elit a diam sodales ornare. Integer rhoncus, quam non eleifend lacinia, enim arcu interdum enim, vel cursus quam ante a magna. Mauris sodales mi ante, a suscipit enim egestas at."

    // MARK: Views

    /// Primary application body
    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Read", systemImage: "book", value: CurrentTab.read) {
                readView
            }
            Tab("Saved", systemImage: "bookmark", value: CurrentTab.saved) {
                savedView
            }
            Tab("Themes", systemImage: "paintbrush", value: CurrentTab.themes) {
                themesView
            }
            Tab(value: CurrentTab.search, role: .search) {
                searchView
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

    /// Read (primary) tab
    var readView: some View {
        ScrollView {
            VStack {
                Group {
                    Text(demoText)
                    Text(demoText)
                    Text(demoText)
                    Text(demoText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineHeight(AttributedString.LineHeight.exact(points: 30))
                // inset on L/R edges; spacing between paragraphs
                .padding(EdgeInsets(top: 8, leading: 24, bottom: 8, trailing: 24))
            }
            // prevent tab bar from covering up bottom few lines
            .padding(EdgeInsets(top: 24, leading: 0, bottom: 75, trailing: 0))
        }
        .background(themeDefault) // TODO: remove in favor of theme service
    }

    /// Saved tab
    var savedView: some View {
        NavigationStack {
            ContentUnavailableView(
                "Saved",
                systemImage: "bookmark",
                description: Text("Coming soon.")
            )
            .navigationTitle("Saved")
            .navigationBarHidden(true)
        }
    }

    /// Themes tab
    var themesView: some View {
        NavigationStack {
            ContentUnavailableView(
                "Themes",
                systemImage: "paintbrush",
                description: Text("Coming soon.")
            )
            .navigationTitle("Themes")
            .navigationBarHidden(true)
        }
    }

    /// Search tab
    var searchView: some View {
        //ContentUnavailableView.search
        ContentUnavailableView(
            "Search",
            systemImage: "magnifyingglass",
            description: Text("Coming soon.")
        )
        .navigationTitle("Saved")
        .navigationBarHidden(true)
    }

    /// Tab bar accessory for Read view
    ///
    /// TODO: Populate via API
    var tabBarAccessory: some View {
        Menu {
            Menu {
                Menu("Matthew") {
                    Text("1")
                    Text("2")
                    Text("3")
                }
                Menu("Mark") {
                    Text("1")
                    Text("2")
                    Text("3")
                }
                Menu("Luke") {
                    Text("1")
                    Text("2")
                    Text("3")
                }
                Menu("John") {
                    Text("1")
                    Text("2")
                    Text("3")
                }
            } label: {
                Label("Books", systemImage: "book.pages")
            }

            Menu {
                Group {
                    Text("NIV")
                    Text("NLT")
                    Text("ESV")
                    Text("TPT")
                }
                .font(.system(.body, design: .serif))
            } label: {
                Label("Translations", systemImage: "textformat") // alt: character.book.closed
            }
            .menuOrder(.fixed)
        } label: {
            Group {
                Text("Matthew 1")
                    .padding(EdgeInsets(top: 0, leading: 15, bottom: 0, trailing: 0))
                Text("NIV")
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

#Preview {
    RootTabView()
}
