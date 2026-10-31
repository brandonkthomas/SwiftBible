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

    /// Is the book/translation picker sheet showing?
    @State private var isPickerSheetPresented = false

    /// Used for Zoom transition
    @Namespace private var presentationNamespace
    private static let presentationID = UUID()

    // MARK: Properties (Private, Dynamic Type)

    /// Previous/next chevron symbol size
    @ScaledMetric(relativeTo: .body) private var chevronSymbolSize: CGFloat = 20

    /// Book/chapter/translation label font size
    @ScaledMetric(relativeTo: .body) private var labelFontSize: CGFloat = 14

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
                    .font(.system(size: chevronSymbolSize,
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
            passagePickerButtonView
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
                    .font(.system(size: chevronSymbolSize,
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

    /// Opens PassagePickerSheetView for choosing book/chapter or translation
    private var passagePickerButtonView: some View {
        Button {
            isPickerSheetPresented = true
        } label: {
            // Label: selected Book/Chapter names & Translation abbreviation
            tabBarAccessoryLabel
                .font(.system(size: labelFontSize,
                              weight: .medium,
                              design: .serif))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary) // Automatically adapts to light/dark
        .sheet(isPresented: $isPickerSheetPresented) {
            PassagePickerSheetView()
                .navigationTransition(.zoom(sourceID: PassagePickerView.presentationID,
                                            in: presentationNamespace))
        }
        .matchedTransitionSource(id: PassagePickerView.presentationID,
                                 in: presentationNamespace)
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
                    .lineLimit(1)
            // no translations should never happen
            case .emptyTranslations,
                 .failed(_):
                Text("Content Unavailable")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .lineLimit(1)
            default:
                ViewThatFits(in: .horizontal) {
                    // Case 1
                    HStack(spacing: 8) {
                        // UI prompts are localized literals; book/chapter/abbreviation are API data
                        // shown verbatim
                        if readerStore.books.isEmpty {
                            Text("Select Translation")
                                .lineLimit(1)
                        } else if let selectedBook = readerStore.selectedBook {
                            Text(verbatim: "\(selectedBook.displayName) \(readerStore.selectedChapter?.displayName ?? "")")
                                .lineLimit(1)
                        } else {
                            Text("Select Book")
                                .lineLimit(1)
                        }
                        Text(verbatim: readerStore.selectedTranslation?.abbreviation ?? "")
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    // Case 2
                    HStack(spacing: 8) {
                        if readerStore.books.isEmpty {
                            Text("Select Translation")
                                .lineLimit(1)
                        } else if let selectedBook = readerStore.selectedBook {
                            Text(verbatim: "\(selectedBook.displayName) \(readerStore.selectedChapter?.displayName ?? "")")
                                .lineLimit(1)
                        } else {
                            Text("Select Book")
                                .lineLimit(1)
                        }
                    }
                    // Case 3
                    HStack(spacing: 8) {
                        if readerStore.books.isEmpty {
                            Text("Select Translation")
                                .minimumScaleFactor(0.8)
                                .lineLimit(1)
                        } else if let selectedBook = readerStore.selectedBook {
                            Text(verbatim: "\(selectedBook.displayName) \(readerStore.selectedChapter?.displayName ?? "")")
                                .minimumScaleFactor(0.8)
                                .lineLimit(1)
                        } else {
                            Text("Select Book")
                                .minimumScaleFactor(0.8)
                                .lineLimit(1)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

#Preview("ContentView: Ready") {
    ContentView()
        .previewEnvironment()
}
