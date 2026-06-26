import SwiftUI

struct RootTabView: View {
    var body: some View {
        TabView {
            NavigationStack {
                ContentUnavailableView(
                    "SwiftBible",
                    systemImage: "book.closed",
                    description: Text("Design preview shell")
                )
                .navigationTitle("Read")
            }
            .tabItem {
                Label("Read", systemImage: "book")
            }
        }
    }
}

#Preview {
    RootTabView()
}
