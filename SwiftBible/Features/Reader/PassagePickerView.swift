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

    // MARK: Properties (Private, Computed)

    /// disable if we are loading OR at start of Bible
    /// - Dont check passageLoadState right now as we want to be able to quickly tap the button while loading
    private var isPrevNavigationDisabled: Bool {
        readerStore.loadState != .loaded //  || readerStore.passageLoadState != .loaded
        || readerStore.previousAdjacentChapterExists == false
    }

    /// disable if we are loading OR at end of Bible
    /// - Dont check passageLoadState right now as we want to be able to quickly tap the button while loading
    private var isNextNavigationDisabled: Bool {
        readerStore.loadState != .loaded //  || readerStore.passageLoadState != .loaded
        || readerStore.nextAdjacentChapterExists == false
    }

    // MARK: Properties (Private, State)

    @State var triggerHaptic: Bool = false

    // MARK: Views

    /// Tab bar accessory for Reader view
    var body: some View {
        HStack(spacing: 15) {
            // Previous Chapter Button
            Button {
                Task {
                    await readerStore.selectAdjacentChapter(.previous)
                }
                triggerHaptic.toggle()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: UIFontMetrics(forTextStyle: .body).scaledValue(for: 20),
                                  weight: .bold))
                    .foregroundStyle(.foreground)
            }
            .disabled(isPrevNavigationDisabled)
            .opacity(isPrevNavigationDisabled ? 0.35 : 1)
            // trigger slight haptic feedback on tap
            .sensoryFeedback(.selection, trigger: triggerHaptic)

            Spacer()

            // Actual Menu Component
            // -- transition between this and VerseActionsView on tabBarAccessory
            booksAndTranslationsMenuView
            .transition(.blurReplace)

            Spacer()

            // Next Chapter Button
            Button {
                Task {
                    await readerStore.selectAdjacentChapter(.next)
                }
                triggerHaptic.toggle()
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: UIFontMetrics(forTextStyle: .body).scaledValue(for: 20),
                                  weight: .bold))
                    .foregroundStyle(.foreground)
            }
            .disabled(isNextNavigationDisabled)
            .opacity(isNextNavigationDisabled ? 0.35 : 1)
            // trigger slight haptic feedback on tap
            .sensoryFeedback(.selection, trigger: triggerHaptic)
        }
        // frame, padding, bounding
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
        .contentShape(Rectangle())
        // allows transition between this and PassagePickerView on tabBarAccessory
        .transition(.blurReplace)
    }

    private var booksAndTranslationsMenuView: some View {
        Menu {
            // Books + Chapters nested menus
            Menu {
                ForEach(readerStore.books) { book in
                    Menu {
                        // TODO: ControlGroup may be to blame for submenus "sticking" in place
                        // for 2 seconds after closing the submenu + scrolling the parent menu
                        ForEach(Array(chapterGroups(for: book).enumerated()), id: \.offset) { _, group in
                            ControlGroup {
                                ForEach(group) { chapter in
                                    Toggle(isOn: chapterSelectionBinding(book: book, chapter: chapter)) {
                                        Text(chapter.displayName)
                                    }
                                }
                            }
                            .controlGroupStyle(.compactMenu)
                            .font(.system(size: UIFontMetrics(forTextStyle: .body).scaledValue(for: 18),
                                          weight: .medium))
                        }
                    } label: {
                        Text(book.displayName)
                    }
                }
            } label: {
                Label("Books", systemImage: "books.vertical")
                if let selectedBook = readerStore.selectedBook,
                   let selectedChapter = readerStore.selectedChapter {
                    Text("\(selectedBook.displayName) \(selectedChapter.number)")
                        .foregroundStyle(Color.secondary)
                }
            }
            .menuOrder(.fixed)

            // Translations menu
            Menu {
                ForEach(readerStore.translations.sorted { $0.title < $1.title }) { translation in
                    Toggle(isOn: translationSelectionBinding(for: translation)) {
                        Text(translation.title)
                        Text(translation.abbreviation)
                            .foregroundStyle(.secondary)
                    }
                }
            } label: {
                Label("Translations", systemImage: "text.book.closed")
                if let selectedTranslation = readerStore.selectedTranslation {
                    Text(selectedTranslation.title)
                        .foregroundStyle(Color.secondary)
                }
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

    private func chapterGroups(for book: Book) -> [[Chapter]] {
        stride(from: 0, to: book.chapters.count, by: 3).map { startIndex in
            Array(book.chapters[startIndex..<min(startIndex + 3, book.chapters.count)])
        }
    }

    private func chapterSelectionBinding(book: Book, chapter: Chapter) -> Binding<Bool> {
        Binding(
            get: {
                readerStore.selectedChapter?.id == chapter.id
            },
            set: { isSelected in
                guard isSelected,
                      readerStore.selectedChapter?.id != chapter.id else { return }

                Task {
                    await readerStore.selectBookAndChapter(bookID: book.id,
                                                           chapterID: chapter.id,
                                                           reloadPassage: true)
                }
            }
        )
    }

    private func translationSelectionBinding(for translation: Translation) -> Binding<Bool> {
        Binding(
            get: {
                readerStore.selectedTranslation?.id == translation.id
            },
            set: { isSelected in
                guard isSelected,
                      readerStore.selectedTranslation?.id != translation.id else { return }

                Task {
                    await readerStore.selectTranslationAndReloadAll(id: translation.id)
                }
            }
        )
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
                                  catalogStore: BibleCatalogStore(repository: repository),
                                  libraryRepository: InMemoryLibraryRepository())

    ContentView()
        .environment(readerStore)
}
