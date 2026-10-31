//
//  PassagePickerSheetView.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 2026-10-30.
//

import SwiftUI

/// Sheet for choosing a book/chapter or a translation
/// Presented from PassagePickerView in the tab bar bottom accessory
struct PassagePickerSheetView: View {

    // MARK: Types

    enum Mode: Hashable {
        case books
        case translations
    }

    // MARK: Properties (Private)

    @Environment(ReaderStore.self) private var readerStore: ReaderStore

    /// for sheet close button / dismiss after selection
    @Environment(\.dismiss) private var dismiss

    // MARK: Properties (Private, State)

    /// Which list is showing (segmented picker)
    @State private var mode: Mode = .books

    /// Book whose chapter grid is currently expanded (only one at a time)
    @State private var expandedBookID: Book.ID?

    /// Row frames + visible scroll area, used to decide whether expanding needs a scroll
    @State private var bookListGeometry = BookListGeometry()

    // MARK: Properties (Private, Layout)

    /// Coordinate space of books ScrollView content (matches ScrollGeometry content coordinates)
    private static let bookListCoordinateSpace = "bookListContent"

    /// Spacing between book header and its chapter grid
    private let bookRowContentSpacing: CGFloat = 12

    /// Spacing between chapter cells (both axes)
    private let chapterGridSpacing: CGFloat = 8

    // MARK: Properties (Private, Dynamic Type)

    /// Minimum chapter cell width; grid fits as many columns as possible
    @ScaledMetric(relativeTo: .body) private var chapterCellMinWidth: CGFloat = 52

    /// Chapter cell height
    @ScaledMetric(relativeTo: .body) private var chapterCellHeight: CGFloat = 40

    // MARK: Properties (Private, Computed)

    private var sortedTranslations: [Translation] {
        readerStore.translations.sorted { $0.title < $1.title }
    }

    // MARK: Views

    var body: some View {
        NavigationStack {
            // Keep both lists alive and toggle visibility instead of switching views
            // Swapping Lists rebuilt the hierarchy mid-animation and snapped the segmented picker
            ZStack {
                booksListView
                    .modeVisibility(mode == .books)
                translationsListView
                    .modeVisibility(mode == .translations)
            }
            .font(.system(.body, design: .serif))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Picker("Translations & Books", selection: $mode) {
                        Text("Books").tag(Mode.books)
                        Text("Translations").tag(Mode.translations)
                    }
                    .pickerStyle(.segmented)
                    .fixedSize()
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close) {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.fraction(0.7)])
        .presentationDragIndicator(.visible)
    }

    // MARK: Views (Books)

    /// Scrollable list of books; tapping a book expands its chapter grid inline
    private var booksListView: some View {
        // ScrollView + VStack instead of List: List (UICollectionView) animates cell height on its
        // own while SwiftUI animates row contents, so expand/collapse tore and ghosted
        // Eager VStack is fine for ~66 books and keeps layout + animation entirely in SwiftUI
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(readerStore.books) { book in
                        bookRowView(book, proxy: proxy)
                            .id(book.id)
                        Divider()
                    }
                }
                .padding(.horizontal, 20)
                .coordinateSpace(.named(Self.bookListCoordinateSpace))
            }
            // Visible content range (excluding toolbar/safe area insets), in content coordinates
            .onScrollGeometryChange(for: ClosedRange<CGFloat>.self) { geometry in
                let top = geometry.contentOffset.y + geometry.contentInsets.top
                let bottom = geometry.contentOffset.y + geometry.containerSize.height
                    - geometry.contentInsets.bottom
                return top...max(top, bottom)
            } action: { _, visibleYRange in
                bookListGeometry.visibleYRange = visibleYRange
            }
            // Open on the currently selected book with its chapters showing
            .onAppear {
                guard let selectedBookID = readerStore.selectedBook?.id else { return }
                expandedBookID = selectedBookID
                proxy.scrollTo(selectedBookID, anchor: .top)
            }
        }
    }

    /// One row per book: header button + (when expanded) chapter grid in the same VStack
    /// Row grows in place and reports its layout frame so expansion can scroll it into view
    private func bookRowView(_ book: Book, proxy: ScrollViewProxy) -> some View {
        let isExpanded = expandedBookID == book.id
        let isSelected = readerStore.selectedBook?.id == book.id

        return VStack(alignment: .leading, spacing: bookRowContentSpacing) {
            Button {
                withAnimation(.default) {
                    toggleExpansion(of: book, proxy: proxy)
                }
            } label: {
                HStack {
                    Text(book.displayName)
                        .fontWeight(isSelected ? .semibold : .regular)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .accessibilityHidden(true) // no need to read this
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityValue(isExpanded ? "Expanded" : "Collapsed")

            if isExpanded {
                chapterGridView(book)
                    .transition(.opacity)
            }
        }
        .padding(.vertical, 11)
        // Keep expanding grid from drawing over rows below while height animates
        .clipped()
        // Layout (not animated) frame; reported once per layout change, not per scroll
        .onGeometryChange(for: CGRect.self) { proxy in
            proxy.frame(in: .named(Self.bookListCoordinateSpace))
        } action: { frame in
            bookListGeometry.rowFrames[book.id] = frame
        }
    }

    private func chapterGridView(_ book: Book) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: chapterCellMinWidth),
                                     spacing: chapterGridSpacing)],
                  spacing: chapterGridSpacing) {
            ForEach(book.chapters) { chapter in
                chapterCellView(book: book, chapter: chapter)
            }
        }
    }

    @ViewBuilder
    private func chapterCellView(book: Book, chapter: Chapter) -> some View {
        let isSelected = readerStore.selectedChapter?.id == chapter.id

        // verbatim: chapter name is API data, not app UI text
        // Same button style + frame for every cell so selected cell doesn't add height to its row
        Button {
            if isSelected {
                dismiss()
            } else {
                select(book: book, chapter: chapter)
            }
        } label: {
            Text(verbatim: chapter.displayName)
                .foregroundStyle(isSelected ? Color.white : Color.primary)
                .frame(width: chapterCellHeight, height: chapterCellHeight)
                .background {
                    if isSelected {
                        Circle().fill(.tint)
                    }
                }
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: Views (Translations)

    private var translationsListView: some View {
        List(sortedTranslations) { translation in
            let isSelected = readerStore.selectedTranslation?.id == translation.id
            Button {
                select(translation: translation)
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(verbatim: translation.title)
                        Text(verbatim: translation.abbreviation)
                            .font(.system(.caption, design: .serif))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if isSelected {
                        Image(systemName: "checkmark")
                            .fontWeight(.semibold)
                            .foregroundStyle(.tint)
                            .accessibilityHidden(true)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(isSelected ? .isSelected : [])
        }
        .listStyle(.plain)
    }

    // MARK: Functions (Private)

    /// Expand/collapse a book; call inside withAnimation so scroll + layout animate together
    ///
    /// Only scrolls when the expanded book would end up cut off (e.g. a grid collapsing above
    /// pushes it off the top, or its own grid runs past the bottom)
    private func toggleExpansion(of book: Book, proxy: ScrollViewProxy) {
        guard expandedBookID != book.id else {
            expandedBookID = nil
            return
        }

        // Predict against current layout before mutating state
        let anchor = scrollAnchorIfCutOff(expanding: book)

        expandedBookID = book.id

        if let anchor {
            proxy.scrollTo(book.id, anchor: anchor)
        }
    }

    /// Predicts tapped book's expanded frame and returns the anchor to scroll it to, or nil if
    /// it will be fully visible where it lands
    /// - .top: top would be cut off, or expanded row is taller than visible area
    /// - .bottom: only bottom would be cut off (minimal scroll up)
    private func scrollAnchorIfCutOff(expanding book: Book) -> UnitPoint? {
        guard let tappedFrame = bookListGeometry.rowFrames[book.id] else { return nil }
        let visible = bookListGeometry.visibleYRange

        // Collapsing row above shrinks to a collapsed height (same as tapped row's current)
        var newMinY = tappedFrame.minY
        if let expandedBookID,
           let expandedFrame = bookListGeometry.rowFrames[expandedBookID],
           expandedFrame.minY < tappedFrame.minY {
            newMinY -= expandedFrame.height - tappedFrame.height
        }

        let expandedHeight = tappedFrame.height
            + bookRowContentSpacing
            + predictedChapterGridHeight(for: book, width: tappedFrame.width)
        let newMaxY = newMinY + expandedHeight

        if newMinY < visible.lowerBound
            || expandedHeight > visible.upperBound - visible.lowerBound {
            return .top
        }
        if newMaxY > visible.upperBound {
            return .bottom
        }
        return nil
    }

    /// Mirrors LazyVGrid adaptive column math in chapterGridView
    private func predictedChapterGridHeight(for book: Book, width: CGFloat) -> CGFloat {
        let columns = max(1, Int((width + chapterGridSpacing) / (chapterCellMinWidth + chapterGridSpacing)))
        let rows = (book.chapters.count + columns - 1) / columns
        return CGFloat(rows) * chapterCellHeight + CGFloat(max(rows - 1, 0)) * chapterGridSpacing
    }

    private func select(book: Book, chapter: Chapter) {
        Task {
            await readerStore.selectBookAndChapter(bookID: book.id,
                                                   chapterID: chapter.id,
                                                   reloadPassage: true)
        }
        dismiss()
    }

    /// Switching translation reloads books, so jump back to Books list instead of dismissing
    private func select(translation: Translation) {
        guard readerStore.selectedTranslation?.id != translation.id else {
            mode = .books
            return
        }
        Task {
            await readerStore.selectTranslationAndReloadAll(id: translation.id)
        }
        mode = .books
    }
}

/// Geometry cache for the books list
/// Plain class (not @Observable) so per-scroll updates don't invalidate the sheet's body;
/// values are only read on tap
private final class BookListGeometry {
    /// Row frames in books ScrollView content coordinates
    var rowFrames: [Book.ID: CGRect] = [:]
    /// Visible content y-range, excluding toolbar/safe area insets
    var visibleYRange: ClosedRange<CGFloat> = 0...0
}

private extension View {
    /// Hide without removing from hierarchy (preserves scroll position + avoids rebuild)
    func modeVisibility(_ isVisible: Bool) -> some View {
        self
            .opacity(isVisible ? 1 : 0)
            .allowsHitTesting(isVisible)
            .accessibilityHidden(!isVisible)
    }
}

#Preview {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            PassagePickerSheetView()
        }
        .previewEnvironment()
}
