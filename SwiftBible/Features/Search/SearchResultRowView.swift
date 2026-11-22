//
//  SearchResultRowView.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 2026-11-21.
//

import SwiftUI

/// Bible search result card: reference/translation, then the snippet or loaded passage text
///
/// Styled after LibraryRowReadOnlyView
struct SearchResultRowView: View {

    // MARK: Properties

    /// Result to use when drawing this view
    let result: ScriptureSearchResult

    /// Query to highlight when drawing this view
    let query: String

    /// What should we do when we need to open this result's passage in the Read tab?
    let onPassageViewRequested: () async -> Void

    // MARK: Properties (Private, Environment)

    @Environment(SearchStore.self) private var searchStore: SearchStore

    @Environment(BibleCatalogStore.self) private var bibleCatalogStore: BibleCatalogStore

    /// What is the system Dynamic Type setting?
    @Environment(\.dynamicTypeSize) private var systemDynamicTypeSize

    /// What's our current configured theme?
    @Environment(\.readerTheme) private var readerTheme

    // MARK: Properties (Private, Dynamic Type)

    @ScaledMetric(relativeTo: .body) private var fontSize16: CGFloat = 16
    @ScaledMetric(relativeTo: .body) private var frameSize18: CGFloat = 18
    @ScaledMetric(relativeTo: .body) private var frameSize32: CGFloat = 32
    @ScaledMetric(relativeTo: .body) private var symbolSize20: CGFloat = 20

    /// Line height from resolved Theme
    private var passageLineHeight: CGFloat {
        readerTheme.lineHeight(dynamicTypeSize: scriptureDynamicTypeSize)
    }

    /// Text size from resolved Theme
    private var scriptureDynamicTypeSize: DynamicTypeSize {
        readerTheme.scriptureDynamicTypeSize(for: systemDynamicTypeSize)
    }

    /// Loading placeholder height
    private var placeholderHeight: CGFloat {
        passageLineHeight * 3
    }

    // MARK: Properties (Private, State)

    /// Has 1 second passed since we first rendered the empty passage slot?
    @State private var isPassageLoadSpinnerVisible: Bool = false

    // MARK: Properties (Computed)

    /// Non empty snippet from the search API, if any
    private var snippet: String? {
        guard let snippet = result.snippet, !snippet.isEmpty else {
            return nil
        }
        return snippet
    }

    private var translationAbbreviation: String? {
        bibleCatalogStore.translation(for: result.translationID)?.abbreviation
    }

    // MARK: Views

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Row 1: Reference / translation + actions menu
            // At accessibility sizes the labels stack so book names don't break mid-word
            HStack(alignment: systemDynamicTypeSize.isAccessibilitySize ? .top : .center) {
                if systemDynamicTypeSize.isAccessibilitySize {
                    passageLabels(in: AnyLayout(VStackLayout(alignment: .leading, spacing: 2)))
                } else {
                    passageLabels(in: AnyLayout(HStackLayout(spacing: 8)))
                }
                Spacer()
                resultItemMenu
            }

            // Row 2: Snippet, loaded passage text, or loading state
            if let snippet {
                Text(snippet)
                    .font(readerTheme.scriptureFont)
                    .lineHeight(AttributedString.LineHeight.exact(points: passageLineHeight))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .dynamicTypeSize(scriptureDynamicTypeSize)
            } else if let runs = searchStore.passageRuns(for: result) {
                passageText(for: runs)
                    .dynamicTypeSize(scriptureDynamicTypeSize)
            } else {
                Color.clear
                    .frame(height: placeholderHeight)
                    .overlay {
                        if let failure = searchStore.passageLoadFailure(for: result) {
                            passageLoadFailureMessage(failure)
                        } else if isPassageLoadSpinnerVisible {
                            ProgressView()
                                .accessibilityLabel("Loading passage...")
                        }
                    }
                    // task cancelled when LazyVStack rebuilds this row (i.e. scroll offscreen)
                    .task {
                        try? await Task.sleep(for: .seconds(1))
                        // have we been asked to cancel while sleeping?
                        guard !Task.isCancelled else { return }
                        isPassageLoadSpinnerVisible = true
                    }
            }
        }
        .padding([.horizontal, .top], 10)
        .padding(.bottom, 2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(readerTheme.backgroundColor,
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
        // Leading edge (swipe right): Read Passage, same action as the menu item
        .swipeActions(edge: .leading) {
            Button {
                Task {
                    await onPassageViewRequested()
                }
            } label: {
                Label("Read", systemImage: "book.fill")
            }
            .tint(.accent)
        }
        // no-op when the result has a snippet or its chapter is already loaded
        .task {
            await searchStore.loadPassage(for: result)
        }
    }

    /// "..." actions menu; styled to match LibraryRowView's annotation menu
    private var resultItemMenu: some View {
        Menu {
            Button {
                Task {
                    await onPassageViewRequested()
                }
            } label: {
                Label("Read Passage", systemImage: "book")
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: symbolSize20))
                .foregroundStyle(Color(.label))
                // touch target optimization
                .frame(width: frameSize32, height: frameSize18)
                .contentShape(.rect.inset(by: -14))
        }
    }

    /// Passage text styling
    private func passageText(for runs: [RenderedPassageRun]) -> some View {
        PassageTextRenderer.text(for: runs,
                                 readerTheme: readerTheme,
                                 dynamicTypeSize: scriptureDynamicTypeSize,
                                 footnoteMarkerMode: .hidden,
                                 produceLinkAttributes: false) // do NOT want these tap events here
        .font(readerTheme.scriptureFont)
            .lineHeight(AttributedString.LineHeight.exact(points: passageLineHeight))
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Shown when passage could not be loaded
    private func passageLoadFailureMessage(_ failure: LibraryPassageLoadFailure) -> some View {
        Label {
            switch failure {
            case .offline:
                Text("Connect to the Internet to view this passage.")
            case .failed:
                Text("Unable to load this passage.")
            }
        } icon: {
            Image(systemName: failure == .offline ? "wifi.slash" : "exclamationmark.triangle")
        }
        .font(readerTheme.font(.footnote))
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
    }

    /// Reference / translation, side by side or stacked
    private func passageLabels(in layout: AnyLayout) -> some View {
        layout {
            Text(searchStore.referenceLabel(for: result))
            if let translationAbbreviation {
                Text(translationAbbreviation)
                    .foregroundStyle(.secondary)
            }
        }
        .font(readerTheme.font(fixedSize: fontSize16, weight: .medium))
    }
}

#Preview {
    VStack(spacing: 12) {
        SearchResultRowView(result: ScriptureSearchResult(translationID: 1234,
                                                          bookCode: "JHN",
                                                          chapter: 3,
                                                          verseRange: 16...16,
                                                          snippet: "For God so loved the world, that he gave his only Son"),
                            query: "loved world",
                            onPassageViewRequested: {})
        SearchResultRowView(result: ScriptureSearchResult(translationID: 1234,
                                                          bookCode: "GEN",
                                                          chapter: 1,
                                                          verseRange: 1...2,
                                                          snippet: nil),
                            query: "beginning",
                            onPassageViewRequested: {})
    }
    .padding()
    .previewEnvironment()
}
