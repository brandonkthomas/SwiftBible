//
//  ReaderView.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 6/27/26.
//

import SwiftUI

struct ReaderView: View {

    // MARK: Properties (Private)

    /// Read appEnvironment.readerStore environment value from current view environment
    ///
    /// Don't need "\." here because this is a type-based lookup for an observable object
    /// placed into the environment: .environment(readerStore))
    @Environment(ReaderStore.self) private var readerStore: ReaderStore

    private var themeDefault: Color = .init(.systemBackground)
    private var themeOffBlack: Color = .init(red: 0.075, green: 0.075, blue: 0.075)
    private var themeBlack: Color = .init(.black)
    private var themeOffWhite: Color = .init(red: 0.925, green: 0.901, blue: 0.858)
    private var themeWhite: Color = .init(.white)

    private var demoText: String = "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Aliquam ac libero non ipsum convallis suscipit at a tortor. In ligula elit, rhoncus sit amet auctor id, ornare id purus. Nullam neque mauris, luctus euismod malesuada at, tempus et enim. Cras tempus efficitur mauris, non dapibus diam rutrum nec. Praesent sollicitudin massa et elementum efficitur. Interdum et malesuada fames ac ante ipsum primis in faucibus. Phasellus metus ipsum, pharetra sed urna et, facilisis maximus massa. Suspendisse potenti. Curabitur elementum tellus in nulla vulputate eleifend. Sed at pharetra nunc, sed tempus ligula. Vestibulum scelerisque ut enim vel malesuada. Mauris in est sem. Donec mollis dolor vitae mi gravida, eu feugiat est interdum. Sed eu elit a diam sodales ornare. Integer rhoncus, quam non eleifend lacinia, enim arcu interdum enim, vel cursus quam ante a magna. Mauris sodales mi ante, a suscipit enim egestas at."

    // MARK: Views

    /// Reader view
    var body: some View {
        Group {
            if case .failed = readerStore.loadState {
                ContentUnavailableView(
                    "Content Unavailable",
                    systemImage: "exclamationmark.circle",
                    description: Text("An error occurred while loading content.")
                )
            } else {
                mainReaderView
            }
        }
        .background(themeOffWhite) // TODO: remove in favor of theme service
        .task {
            await readerStore.loadTranslations()
        }
    }

    var mainReaderView: some View {
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
    }
}

// MARK: Xcode Canvas Previews

#Preview {
    let repository = FakeBibleRepository()
    let readerStore = ReaderStore(repository: repository)

    ReaderView()
        .environment(readerStore)
}
