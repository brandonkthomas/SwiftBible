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

    // MARK: Properties (Private State)

    @State private var isLeftButtonDisabled: Bool = false
    @State private var isRightButtonDisabled: Bool = false

    // MARK: Views

    /// Tab bar accessory for Reader view
    var body: some View {
        HStack(spacing: 15) {
            Button {
                Task {
                    await readerStore.selectAdjacentChapter(.previous)
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: UIFontMetrics(forTextStyle: .body).scaledValue(for: 20),
                                  weight: .bold))
                    .foregroundStyle(.foreground)
            }
            .disabled(isLeftButtonDisabled)

            Spacer()

            menu
            // allows transition between this and VerseActionsView on tabBarAccessory
            .transition(.blurReplace)

            Spacer()

            Button {
                Task {
                    await readerStore.selectAdjacentChapter(.next)
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: UIFontMetrics(forTextStyle: .body).scaledValue(for: 20),
                                  weight: .bold))
                    .foregroundStyle(.foreground)
            }
            .disabled(isRightButtonDisabled)
        }
        // frame, padding, bounding
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
        .contentShape(Rectangle())
        // allows transition between this and PassagePickerView on tabBarAccessory
        .transition(.blurReplace)
    }

    private var menu: some View {
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
                                    Task {
                                        await readerStore.selectBookAndChapter(bookID: book.id,
                                                                               chapterID: chapter.id,
                                                                               reloadPassage: true)
                                    }
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
                                .foregroundStyle(.secondary)
                        })
                    }
                    else {
                        // Shows a menu item without a tick
                        Button(action: {
                            Task {
                                await readerStore.selectTranslationAndReloadAll(id: translation.id)
                            }
                        }) {
                            Text(translation.title)
                            Text(translation.abbreviation)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } label: {
                Label("Translations", systemImage: "text.book.closed") // was text.redaction
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
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

#Preview("ContentView: Ready") {
    let repository = FakeBibleRepository()
    let readerStore = ReaderStore(repository: repository,
                                  libraryRepository: InMemoryLibraryRepository())

    ContentView()
        .environment(readerStore)
}
