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
    /// Don't need "\." here because this is a type-based lookup for an observable instance
    /// placed into the environment: .environment(readerStore))
    @Environment(ReaderStore.self) private var readerStore: ReaderStore

    /// Calculated -- what is our current system theme?
    @Environment(\.colorScheme) private var colorScheme

    private var demoText: String = "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Aliquam ac libero non ipsum convallis suscipit at a tortor. In ligula elit, rhoncus sit amet auctor id, ornare id purus. Nullam neque mauris, luctus euismod malesuada at, tempus et enim. Cras tempus efficitur mauris, non dapibus diam rutrum nec. Praesent sollicitudin massa et elementum efficitur. Interdum et malesuada fames ac ante ipsum primis in faucibus. Phasellus metus ipsum, pharetra sed urna et, facilisis maximus massa. Suspendisse potenti. Curabitur elementum tellus in nulla vulputate eleifend. Sed at pharetra nunc, sed tempus ligula. Vestibulum scelerisque ut enim vel malesuada. Mauris in est sem. Donec mollis dolor vitae mi gravida, eu feugiat est interdum. Sed eu elit a diam sodales ornare. Integer rhoncus, quam non eleifend lacinia, enim arcu interdum enim, vel cursus quam ante a magna. Mauris sodales mi ante, a suscipit enim egestas at."

    // MARK: Views

    /// Reader view
    var body: some View {
        ZStack {
            // TODO: Store user preference + fix font color to match
            // aka store font alongside theme background
            if colorScheme == .dark {
                AppTheme.themeOffBlack
                    .ignoresSafeArea()
            } else {
                AppTheme.themeOffWhite
                    .ignoresSafeArea()
            }

            // Show corresponding View to current loadState
            // This will automatically refresh when we change @Observable loadState
            switch readerStore.loadState {
            case .loading:
                ProgressView()
                    .controlSize(.large)
            case .emptyTranslations:
                // no translations should never happen
                ContentUnavailableView(
                    "Content Unavailable",
                    systemImage: "text.page.slash",
                    description: Text("An error occurred while loading Bibles.")
                )
            case .emptyBooks:
                ContentUnavailableView(
                    "Content Unavailable",
                    systemImage: "text.page.slash",
                    description: Text("The selected translation is unavailable.")
                )
            case .emptyChapters:
                ContentUnavailableView(
                    "Content Unavailable",
                    systemImage: "text.page.slash",
                    description: Text("The selected book is unavailable.")
                )
            case .failed(let message):
                ContentUnavailableView(
                    "Content Unavailable",
                    systemImage: "text.page.slash",
                    description: Text(message)
                )
            default:
                if readerStore.selectedReference != nil {
                    mainReaderView
                } else {
                    ContentUnavailableView {
                        Label {
                            Text("No Passage Selected")
                        } icon: {
                            Image(systemName: "rectangle.dashed")
                                .rotationEffect(.degrees(90)) // Rotate only the image
                        }
                    } description: {
                        Text("Select a passage using the picker below.")
                    }
                }
            }
        }
        .task {
            await readerStore.loadTranslationsAndBooks()
        }
        .navigationTitle(readerStore.selectedReferenceFriendlyName ?? "No Passage Selected")
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

#Preview("Loaded") {
    let repository = FakeBibleRepository()
    let readerStore = ReaderStore(repository: repository)

    ReaderView()
        .environment(readerStore)
}

#Preview("Failed") {
    let repository = FakeBibleRepository(throwWhenLoadingTranslations: true)
    let readerStore = ReaderStore(repository: repository)

    ReaderView()
        .environment(readerStore)
}

#Preview("No Translations") {
    let repository = FakeBibleRepository(translations: [])
    let readerStore = ReaderStore(repository: repository)

    ReaderView()
        .environment(readerStore)
}

#Preview("No Books") {
    let repository = FakeBibleRepository(books: [])
    let readerStore = ReaderStore(repository: repository)

    ReaderView()
        .environment(readerStore)
}

#Preview("No Chapters") {
    let repository = FakeBibleRepository(books: FakeBibleRepository.booksWithoutChapters)
    let readerStore = ReaderStore(repository: repository)

    ReaderView()
        .environment(readerStore)
}

#Preview("Loading") {
    let repository = FakeBibleRepository(forceLoadingState: true)
    let readerStore = ReaderStore(repository: repository)

    ReaderView()
        .environment(readerStore)
}
