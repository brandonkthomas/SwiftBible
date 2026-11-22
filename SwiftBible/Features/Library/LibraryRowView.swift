//
//  LibraryRowView.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 2026-07-19.
//

import SwiftUI

struct LibraryRowView: View {

    // MARK: Properties

    /// Consolidated entry point for required data
    var data: LibraryRowViewData

    /// Is this row selected? (nil = not selecting)
    let isRowSelected: Bool?

    /// What should we do when we need to change this row (annotation)'s highlight color?
    let onHighlightColorChangeRequested: (VerseAnnotationHighlightColor) -> Void

    /// What should we do when we need to delete this row (annotation)?
    let onDeleteRequested: () -> Void

    /// What should we do when we need to open this row's passage in the Read tab?
    let onPassageViewRequested: () async -> Void

    /// What should we do when we need to open the Annotation Editor sheet?
    let onAnnotationEditorRequested: () -> Void

    /// What should we do when we need to mark this row as selected in Library's edit mode?
    let onRowSelected: () -> Void

    // MARK: Properties (Private, Dynamic Type)

    @ScaledMetric(relativeTo: .body) private var frameSize18: CGFloat = 18
    @ScaledMetric(relativeTo: .body) private var frameSize32: CGFloat = 32
    @ScaledMetric(relativeTo: .body) private var symbolSize20: CGFloat = 20

    // MARK: Properties (Private, State)

    @State private var isHighlightPopoverPresented: Bool = false

    /// Have we selected the Delete option for this row + need to show confirmation?
    @State private var isDeleteConfirmationVisible: Bool = false

    // MARK: Views

    var body: some View {
        // Read-only card; this view layers the write actions on top
        LibraryRowReadOnlyView(data: data) {
            rowTrailingControl
        }
        // Selected border: always present and faded with opacity (rather than inserted with
        // `if`) so the change animates in place
        // strokeBorder draws inside the shape, so the card's size never changes
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(.accent, lineWidth: 2)
                .opacity(isRowSelected == true ? 1 : 0)
        }
        // Outside a List, only takes effect inside swipeActionsContainer() (iOS 27+)
        // Opens the same per-row confirmation as the menu's Delete, so the dialog is
        //   anchored to this card and driven by this card's own state
        .swipeActions {
            if isRowSelected == nil { // NOT in edit mode
                Button {
                    isDeleteConfirmationVisible = true
                } label: {
                    Label("Delete", systemImage: "trash.fill")
                }
                .tint(Color(.systemRed))
                Button {
                    if data.annotation.content.type == .highlight {
                        isHighlightPopoverPresented = true
                    } else {
                        onAnnotationEditorRequested()
                    }
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
                .tint(Color(.systemGray))
            }
        }
        // other edge -- Read Passage action
        .swipeActions(edge: .leading) {
            if isRowSelected == nil { // NOT in edit mode
                Button {
                    Task {
                        await onPassageViewRequested()
                    }
                } label: {
                    Label("Read", systemImage: "book.fill")
                }
                .tint(.accent)
            }
        }
        // highlight popover
        .popover(isPresented: $isHighlightPopoverPresented,
                 attachmentAnchor: .point(.trailing),
                 arrowEdge: .trailing,
                 content: {
            HighlightPickerView(
                onCreateRequested: { color in
                    onHighlightColorChangeRequested(color)
                },
                onDeleteRequested: {
                    onDeleteRequested()
                },
                existingHighlightColors: data.annotation.highlightColor.map { [$0] }
            )
        })
        // Selection state
        // In selection mode, one layer covers the whole card so taps toggle selection
        // instead of reaching the expand button / menu underneath
        .overlay {
            if let isRowSelected {
                // Color.clear fills the card (a Button would shrink to its label's size)
                // Tap gesture rather than Button: a Button also fires at the end of a
                // horizontal drag, so swiping a card would toggle it
                Color.clear
                    // include transparent areas
                    .contentShape(.rect)
                    .onTapGesture {
                        onRowSelected()
                    }
                    // A tap gesture has no accessibility semantics; describe it as a
                    // selectable button for VoiceOver
                    .accessibilityElement()
                    .accessibilityLabel(data.passageLabel)
                    .accessibilityAddTraits(isRowSelected ? [.isButton, .isSelected] : .isButton)
                    .accessibilityAction {
                        onRowSelected()
                    }
            }
        }
        // Haptic Touch (context) menu
        .contextMenu {
            if isRowSelected == nil { // NOT in edit mode
                annotationItems
            }
        }
    }

    /// Action menu / select circle
    ///
    /// Animated by the withAnimation around the selection change in LibraryView;
    /// withAnimation inside body runs while building views, so it animates nothing
    @ViewBuilder
    private var rowTrailingControl: some View {
        if isRowSelected == true {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.accent)
        } else if isRowSelected == false {
            Image(systemName: "circle")
                .foregroundStyle(.accent)
        } else {
            annotationItemMenu
        }
    }

    /// All items in annotation submenu
    private var annotationItemMenu: some View {
        Menu {
            annotationItems
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: symbolSize20))
                .foregroundStyle(Color(.label))
                // touch target optimization
                .frame(width: frameSize32, height: frameSize18)
                .contentShape(.rect.inset(by: -14))
        }
        // Shared by the menu's Delete and the swipe action; on iOS 26+ it presents as a
        // popover pointing at the view it's attached to (this card's "..." button)
        .confirmationDialog("Delete Annotation",
                            isPresented: $isDeleteConfirmationVisible) {
            Button("Delete Annotation", role: .destructive) {
                onDeleteRequested()
            }
        } message: {
            Text("This annotation will be permanently deleted.")
        }
    }

    /// Item group; reused by annotationItemMenu wrapper + contextMenu for whole row
    private var annotationItems: some View {
        Group {
            Text("Created on \(data.annotation.createdAt.formatted(date: .long, time: .shortened))")
            Divider()

            // Read Passage
            Button {
                Task {
                    await onPassageViewRequested()
                }
            } label: {
                Label("Read Passage", systemImage: "book")
            }

            // Edit Annotation
            Button {
                if data.annotation.content.type == .highlight {
                    isHighlightPopoverPresented = true
                } else {
                    onAnnotationEditorRequested()
                }
            } label: {
                Label("Edit Annotation", systemImage: "pencil")
            }

            // Delete
            Button(role: .destructive) {
                isDeleteConfirmationVisible = true
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        // Shared by the menu's Delete and the swipe action; on iOS 26+ it presents as a
        // popover pointing at the view it's attached to (this card's "..." button)
        .confirmationDialog("Delete Annotation",
                            isPresented: $isDeleteConfirmationVisible) {
            Button("Delete Annotation", role: .destructive) {
                onDeleteRequested()
            }
        } message: {
            Text("This annotation will be permanently deleted.")
        }
    }
}

// MARK: Xcode Canvas Previews

#Preview {
    let environment = PreviewEnvironment()

    LibraryRowViewPreviewHost(libraryStore: environment.libraryStore,
                              catalogStore: environment.catalogStore)
}

/// Preview-only host: loads each sample's passage before building its `LibraryRowViewData`,
/// mirroring the real load path in LibraryView
private struct LibraryRowViewPreviewHost: View {
    let libraryStore: LibraryStore
    let catalogStore: BibleCatalogStore

    private let annotations = [
        PreviewFixtures.sampleHighlightAnnotation,
        PreviewFixtures.sampleNoteAnnotation,
        PreviewFixtures.sampleTagsAnnotation
    ]

    var body: some View {
        VStack(spacing: 16) {
            ForEach(annotations) { annotation in
                LibraryRowView(
                    data: LibraryRowViewData(annotation: annotation,
                                             bibleCatalogStore: catalogStore,
                                             libraryStore: libraryStore),
                    isRowSelected: nil,
                    onHighlightColorChangeRequested: { color in },
                    onDeleteRequested: {},
                    onPassageViewRequested: {},
                    onAnnotationEditorRequested: {},
                    onRowSelected: {})
            }
        }
        .padding()
        .background(Color(.systemGroupedBackground))
        .task {
            for annotation in annotations {
                await libraryStore.loadPassage(for: annotation)
            }
        }
    }
}
