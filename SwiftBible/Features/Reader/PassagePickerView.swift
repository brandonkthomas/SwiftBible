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
                            if readerStore.selectedChapter?.id == chapter.id {
                                // Shows a menu item with a tick
                                Toggle(isOn: .constant(true), label: {
                                    Text(chapter.displayName)
                                })
                            }
                            else {
                                // Shows a menu item without a tick
                                Button(action: {
                                    readerStore.selectBookAndChapter(bookID: book.id,
                                                                     chapterID: chapter.id)
                                }) {
                                    Text(chapter.displayName)
                                }
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
                ForEach(readerStore.translations.sorted { $0.title < $1.title }) { translation in
                    if readerStore.selectedTranslation?.id == translation.id {
                        // Shows a menu item with a tick
                        Toggle(isOn: .constant(true), label: {
                            Text(translation.title)
                            Text(translation.abbreviation)
                                .foregroundColor(.secondary)
                        })
                    }
                    else {
                        // Shows a menu item without a tick
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
                }
            } label: {
                Label("Translations", systemImage: "text.redaction")
            }
            .menuOrder(.fixed)
        } label: {
            // Label: selected Book/Chapter names & Translation abbreviation
            tabBarAccessoryLabel
                .font(.system(size: UIFontMetrics(forTextStyle: .body).scaledValue(for: 14),
                              weight: .medium,
                              design: .serif))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
        }
        .foregroundStyle(.primary) // Automatically adapts to light/dark
        .menuOrder(.fixed)
    }

    /// TabBarAccessory label view
    private var tabBarAccessoryLabel: some View {
        Group {
            // Show corresponding View to current loadState
            // This will automatically refresh when we change @Observable loadState
            switch readerStore.loadState {
            case .emptyBooks:
                Text("Select Translation")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            // no translations should never happen
            case .emptyTranslations,
                 .failed(_):
                Text("Content Unavailable")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            default:
                HStack(spacing: 8) {
                    Text(
                        "\(readerStore.selectedBook?.displayName ?? "Select Book") \(readerStore.selectedChapter?.displayName ?? "")"
                    )
                    Text("\(readerStore.selectedTranslation?.abbreviation ?? "")")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

#Preview("ContentView: Ready") {
    let repository = FakeBibleRepository()
    let readerStore = ReaderStore(repository: repository)

    ContentView()
        .environment(readerStore)
}
