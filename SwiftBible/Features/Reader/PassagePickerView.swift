//
//  PassagePickerView.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 6/28/26.
//

import SwiftUI
import TipKit

struct PassagePickerView: View {

    // MARK: Properties (Private)

    /// Read appEnvironment.readerStore environment value from current view environment
    ///
    /// Don't need "\." here because this is a type-based lookup for an observable instance
    /// placed into the environment: .environment(readerStore))
    @Environment(ReaderStore.self) private var readerStore: ReaderStore

    /// What's our current configured theme?
    @Environment(\.readerTheme) private var readerTheme

    // MARK: Properties (Private, TipKit)

    private let passagePickerTip = PassagePickerTip()

    // MARK: Properties (Private, Computed)

    /// disable if we are loading OR at start of Bible
    /// - Dont check passageLoadState right now as we want to be able to quickly tap the button while loading
    private var isPrevNavigationDisabled: Bool {
        readerStore.loadState != .loaded //  || readerStore.passageLoadState != .loaded
        || !readerStore.previousAdjacentChapterExists
    }

    /// disable if we are loading OR at end of Bible
    /// - Dont check passageLoadState right now as we want to be able to quickly tap the button while loading
    private var isNextNavigationDisabled: Bool {
        readerStore.loadState != .loaded //  || readerStore.passageLoadState != .loaded
        || !readerStore.nextAdjacentChapterExists
    }

    // MARK: Properties (Private, State)

    @State var triggerHaptic: Bool = false

    /// Is the book/translation picker sheet showing?
    @State private var isPickerSheetPresented = false

    /// Used for Zoom transition
    @Namespace private var presentationNamespace
    private static let presentationID = UUID()

    // MARK: Properties (Private, Dynamic Type)

    // The accessory's height is fixed, so these stop growing at the largest standard size;
    // each control shows the Large Content Viewer instead (long press)

    private static let chevronSymbolBaseSize: CGFloat = 20
    private static let labelFontBaseSize: CGFloat = 14

    @ScaledMetric(relativeTo: .body) private var scaledChevronSymbolSize = PassagePickerView.chevronSymbolBaseSize
    @ScaledMetric(relativeTo: .body) private var scaledLabelFontSize = PassagePickerView.labelFontBaseSize

    /// Previous/next chevron symbol size
    private var chevronSymbolSize: CGFloat {
        ScaledMetricLimit.capped(scaledChevronSymbolSize, base: Self.chevronSymbolBaseSize)
    }

    /// Book/chapter/translation label font size
    private var labelFontSize: CGFloat {
        ScaledMetricLimit.capped(scaledLabelFontSize, base: Self.labelFontBaseSize)
    }

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
                    // 44 pt minimum tap area
                    // keep chevron at the edge and extend area inward
                    .frame(minWidth: 44, minHeight: 44, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Previous Chapter")
            .accessibilityShowsLargeContentViewer()
            .disabled(isPrevNavigationDisabled)
            .opacity(isPrevNavigationDisabled ? 0.35 : 1)
            // trigger slight haptic feedback on tap
            .sensoryFeedback(.selection, trigger: triggerHaptic)

            Spacer()

            // Actual Menu Component
            // -- transition between this and VerseActionsView on tabBarAccessory
            passagePickerButtonView
            .transition(.blurReplace)
            // its tip floats above the accessory from ReaderView (inline, not a popover)

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
                    // 44 pt minimum tap area
                    // keep chevron at the edge and extend area inward
                    .frame(minWidth: 44, minHeight: 44, alignment: .trailing)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Next Chapter")
            .accessibilityShowsLargeContentViewer()
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
            passagePickerTip.invalidate(reason: .actionPerformed)
            isPickerSheetPresented = true
        } label: {
            // Label: selected Book/Chapter names & Translation abbreviation
            tabBarAccessoryLabel
                .font(readerTheme.font(fixedSize: labelFontSize, weight: .medium))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary) // Automatically adapts to light/dark
        // label truncates at the largest sizes; a long press shows it in full
        .accessibilityShowsLargeContentViewer()
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
            case .offline:
                Text("Offline")
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
