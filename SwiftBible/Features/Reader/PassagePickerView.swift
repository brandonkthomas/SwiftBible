//
//  PassagePickerView.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 6/28/26.
//

import SwiftUI

struct PassagePickerView: View {

    // MARK: Properties (Private)

    /// Read appEnvironment.readerStore environment value from current view environment
    ///
    /// Don't need "\." here because this is a type-based lookup for an observable instance
    /// placed into the environment: .environment(readerStore))
    @Environment(ReaderStore.self) private var readerStore: ReaderStore

    // MARK: Views

    /// Tab bar accessory for Reader view
    var body: some View {
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
                case .emptyBooks:
                    Text("Select Translation")
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

    /// Default TabBarAccessory view (Book 1  NIV)
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

#Preview("ContentView: Ready") {
    let repository = FakeBibleRepository()
    let readerStore = ReaderStore(repository: repository)

    ContentView()
        .environment(readerStore)
}
