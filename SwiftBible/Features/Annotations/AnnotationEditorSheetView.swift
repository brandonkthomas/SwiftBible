//
//  AnnotationEditorSheetView.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 2026-07-25.
//

import SwiftUI

struct AnnotationEditorSheetView: View {

    // MARK: Properties

    // we need two-way bindings ($editor.noteText) into @Observable class that we don't own
    // @State is only used when this view would be creating the object
    @Bindable var editor: AnnotationEditor

    /// Used for calculation of the sheet's title
    let bibleCatalogStore: BibleCatalogStore

    /// Fired after we've saved so that parent views can react as needed
    var onSaveCompleted: (() -> Void)?

    // MARK: Properties (Private)

    /// Shared animation for tag chip selection/reflow
    private let glassMorph: Animation = .smooth(duration: 0.3)

    /// for sheet close button
    @Environment(\.dismiss) private var dismiss

    /// What's our current configured theme?
    @Environment(\.readerTheme) private var readerTheme

    // MARK: Properties (Private, State)

    private enum FocusedField: Hashable {
        case note
        case newTag
    }
    /// Which field is focused right now (if any) -- note / new tag?
    @FocusState private var focusedField: FocusedField?

//    /// Used for grid liquid glass effect
//    @Namespace private var tagGridNamespace

    /// Are we currently creating a new tag using the UI?
    @State private var isCreatingTag = false
    /// What is our new tag's text (temporary)?
    @State private var newTagText = ""

    /// Measured height of sheet content (used for fit-to-content detent)
    /// NavigationStack always wants to fill, so `.presentationSizing(.fitted)`
    /// can't shrink sheet; measuring content and pinning `.height` detent is ideal way to wrap
    /// to content while keeping native chrome
    @State private var contentHeight: CGFloat = 320

    // MARK: Properties (Private, Computed)

    private var sheetTitle: String {
        return bibleCatalogStore.friendlyPassageName(for: editor.reference,
                                                     selectedVerses: editor.selectedVerses)
    }

    private var sheetSubtitle: String {
        return bibleCatalogStore.translation(for: editor.reference.translationID)?.abbreviation ?? ""
    }

    /// Order: selected, vocab
    /// Filter by selection to avoid showing dupes
    private var visibleTags: [String] {
        editor.tags
        + editor.tagVocabulary.filter {
            !editor[tagIsSelected: $0]
        }
    }

    // MARK: Properties (Private, Dynamic Type)

    @ScaledMetric(relativeTo: .caption) private var captionSymbolSize9: CGFloat = 9
    @ScaledMetric(relativeTo: .caption) private var captionSymbolSize13: CGFloat = 13
    @ScaledMetric(relativeTo: .caption) private var captionFrameSize18: CGFloat = 18
    @ScaledMetric(relativeTo: .caption) private var captionFrameSize140: CGFloat = 140

    // MARK: Views

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                // Tags section
                Label("Tags", systemImage: "tag")
                    .textCase(.uppercase)
                    .font(readerTheme.font(.caption2))
                    .foregroundStyle(.secondary)

                tagChipsView

                Divider()

                // Note section
                Label("Note", systemImage: "text.alignleft")
                    .textCase(.uppercase)
                    .font(readerTheme.font(.caption2))
                    .foregroundStyle(.secondary)

                TextField("Write a note about this passage...",
                          text: $editor.noteText,
                          axis: .vertical)
                .lineLimit(1...8)
                // padding before glassEffect (glass wraps padded field)
                .padding()
                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
                .focused($focusedField, equals: .note)
            }
            .font(readerTheme.font(.body))
            .padding(EdgeInsets(top: 4, leading: 20, bottom: 16, trailing: 20))
            // Measure at ideal height so the measurement doesn't depend on the sheet's height
            // (horizontal ScrollView otherwise absorbs proposed height -> detent feedback loop)
            .fixedSize(horizontal: false, vertical: true)
            // Measure padded content so sheet can hug it; add fixed allowance for inline navigation bar
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.size.height
            } action: { height in
                // Ignore sub-point jitter so the detent can't oscillate
                let newHeight = (height + navigationBarAllowance).rounded(.up)
                if abs(newHeight - contentHeight) >= 1 {
                    contentHeight = newHeight
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)
            .navigationTitle(sheetTitle)
            .navigationSubtitle(sheetSubtitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Label("Cancel", systemImage: "xmark")
                            .labelStyle(.iconOnly)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        // perform actual save + let caller know, then dismiss sheet
                        editor.save()
                        onSaveCompleted?()
                        dismiss()
                    } label: {
                        Label("Save", systemImage: "checkmark")
                            .labelStyle(.iconOnly)
                    }
                    .disabled(!editor.canSave)
                }
            }
            // load on open; focus Note field
            .task {
                editor.load()
                focusedField = .note
            }
            // Triggered when focus leaves tag input; morph input back into +Tag chip
            // Handle here to guarantee note is first responder (avoid keyboard drops)
            .onChange(of: focusedField) { _, newValue in
                if newValue != .newTag, isCreatingTag {
                    isCreatingTag = false
                }
            }
        }
        // Hug the measured content instead of using a large/medium detent.
        .presentationDetents([.height(contentHeight)])
    }

    /// Fixed vertical allowance for inline navigation bar drawn above content (title row/padding)
    private let navigationBarAllowance: CGFloat = 60

    /// Horizontally scrollable, two-row tag chip bar
    ///
    /// No `GlassEffectContainer`: we coordinate/morph glass shapes of children, so swapping
    /// small "+ Tag" capsule for wider input capsule produced a ghosting smear
    /// Each chip keeps its own `.glassEffect`; without GlassEffectContainer, swap is instant
    private var tagChipsView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            // TwoRowFlowLayout (not LazyHGrid which is column-major)
//            GlassEffectContainer(spacing: 8) {
            TwoRowFlowLayout(spacing: 8) {
                // "+ Tag" cell which swaps to an inline text field
                addTagCell

                // Existing / suggested tags
                ForEach(visibleTags, id: \.self) { tag in
                    tagChipButtonView(tag: tag)
                }
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
//            }
        }
    }

    /// One grid cell: either "+ Tag" chip or inline tag input
    /// Shared-`glassEffectID` morph cross-faded both views at once (flickered)
    @ViewBuilder
    private var addTagCell: some View {
        if isCreatingTag {
            tagInputField
        } else {
            addTagButton
        }
    }

    /// collapsed "+ Tag" chip
    private var addTagButton: some View {
        Button {
            // Only reveal here
            // Focusing is field's .onAppear; setting `focusedField = .newTag` now would target
            // field that doesnt exist yet which causes SwiftUI to drop the request
            isCreatingTag = true
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "plus")
                Text("Tag")
            }
            .font(readerTheme.font(.caption, weight: .semibold))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .capsule)
    }

    /// inline tag input
    /// Single line field plus circular blue add button together in one glass capsule
    /// Fixed width keeps cell from collapsing LazyHGrid
    private var tagInputField: some View {
        HStack(spacing: 6) {
            TextField("New tag", text: $newTagText)
                .font(readerTheme.font(.caption, weight: .semibold))
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .submitLabel(.done)
                .focused($focusedField, equals: .newTag)
                .frame(width: captionFrameSize140)
                .onSubmit(submitNewTag)
                // Focus once field is actually in hierarchy AND ready to accept first responder
                // onAppear alone fires too early (field exists but can't respond yet, so request
                // is dropped)
                // Async hop moves set to next runloop (transfer responder immediately)
                .onAppear {
                    DispatchQueue.main.async { focusedField = .newTag }
                }

            // Add button
            Button(action: submitNewTag) {
                Image(systemName: "plus")
                    .font(readerTheme.font(fixedSize: captionSymbolSize13, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: captionFrameSize18, height: captionFrameSize18)
                    .background(Circle().fill(.blue))
            }
            .buttonStyle(.plain)
        }
        .padding(EdgeInsets(top: 6, leading: 14, bottom: 6, trailing: 6))
        .glassEffect(.regular.interactive(), in: .capsule)
    }

    /// One tag chip
    /// Selected chips shown w/ "x"
    /// Tapping toggles selection with the shared morph animation so chips reflow smoothly
    private func tagChipButtonView(tag: String) -> some View {
        let isSelected = editor[tagIsSelected: tag]

        return Button {
            withAnimation(glassMorph) {
                editor[tagIsSelected: tag] = !isSelected
            }
        } label: {
            // "x" stays in hierarchy; directly animate width/opacity instead of conditional insert/remove
            // Fades do not seem to survive glass compositing
            HStack(spacing: 0) {
                Text(tag)
                Image(systemName: "xmark")
                    .font(.system(size: captionSymbolSize9, weight: .bold))
                    .padding(.leading, 4)
                    .frame(width: isSelected ? nil : 0, alignment: .leading)
                    .clipped()
                    .opacity(isSelected ? 1 : 0)
                    .accessibilityHidden(!isSelected)
            }
            .font(readerTheme.font(.caption, weight: .semibold))
            .foregroundStyle(isSelected ? Color.white : Color.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .glassEffect(isSelected
                     ? .regular.tint(.accentColor).interactive()
                     : .regular.interactive(),
                     in: .capsule)
//        .glassEffectID(tag.hashValue, in: tagGridNamespace)
    }

    // MARK: Functions (Private)

    /// Commit typed tag, then hand first responder back to Note
    ///
    /// Collapsing input back to "+ Tag" chip is done by body's `.onChange(of: focusedField)`
    /// once Note has focus (avoid keyboard drops / race condition)
    private func submitNewTag() {
        editor[tagIsSelected: newTagText] = true
        newTagText = ""
        focusedField = .note
    }
}

// MARK: Xcode Canvas Previews

private extension AnnotationEditor {
    static func previewEditor() -> AnnotationEditor {
        let repository = InMemoryLibraryRepository()
        let reference = ScriptureReference(translationID: 1234,
                                           bookCode: "GEN",
                                           chapter: 1)!   // whole-chapter, like the app

        try? repository.save(VerseAnnotation(reference: reference,
                                             selectedVerses: 1...3,
                                             content: .note("Existing note"))!)
        try? repository.save(VerseAnnotation(reference: reference,
                                             selectedVerses: 1...3,
                                             content: .tags(["Creation", "Memorize"]))!)

        return AnnotationEditor(reference: reference,
                                selectedVerses: 1...3,
                                libraryRepository: repository)
    }
}

#Preview {
    AnnotationEditorSheetView(editor: .previewEditor(),
                              bibleCatalogStore: BibleCatalogStore(repository: FakeBibleRepository()))
}
