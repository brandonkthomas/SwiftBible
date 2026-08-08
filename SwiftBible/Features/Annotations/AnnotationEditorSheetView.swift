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

    // MARK: Properties (Private)

    /// for sheet close button
    @Environment(\.dismiss) private var dismiss

    /// Namespace for liquid glass effect on tag chips
    @Namespace private var tagChipBarNamespace

    private enum FocusedField: Hashable {
        case note
        case newTag
    }
    /// Which field is focused right now (if any) -- note / new tag?
    @FocusState private var focusedField: FocusedField?

    /// Are we currently creating a new tag using the UI?
    @State private var isCreatingTag = false
    /// What is our new tag's text (temporary)?
    @State private var newTagText = ""

    // MARK: Properties (Computed, Private)

    /// Title for this view (TODO:  Genesis 1:1-3)
    private var sheetTitle: String {
        //        guard let bookAndChapter = passage.referenceBookAndChapterDisplayName else {
        return "Notes & Tags"
        //        }
        //        return "\(bookAndChapter):\(verseRange.displayText)"
    }

    /// TODO: calculate based on width (if tags will go off screen, split into 2 rows; else show 1)
    private var rows: [GridItem] {
//        isCollapsed ? [GridItem(.fixed(36))] : [GridItem(.fixed(36)), GridItem(.fixed(36))]
        [GridItem(.fixed(36)), GridItem(.fixed(36))]
    }

    ///
    private var visibleTags: [String] {
        editor.tags
        + editor.tagVocabulary.filter {
            !editor[tagIsSelected: $0]
        }
    }

    // MARK: Views

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                // Tags section
                Label("TAGS", systemImage: "tag")
                    .font(.system(size: 11, weight: .regular, design: .serif))
                    .foregroundStyle(.secondary)

                tagChipsView

                Divider()

                // Note section
                Label("NOTE", systemImage: "text.alignleft")
                    .font(.system(size: 11, weight: .regular, design: .serif))
                    .foregroundStyle(.secondary)

                TextField("Write a note about this passage...",
                          text: $editor.noteText,
                          axis: .vertical)
                .onSubmit {
                    // ...
                }
                .lineLimit(1...8)
                // padding before glassEffect (glass wraps padded field)
                .padding()
                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
                .focused($focusedField, equals: .note)
            }
            .font(.system(.body, design: .serif))
            // inset on top/bottom
            .padding(EdgeInsets(top: 4, leading: 24, bottom: 0, trailing: 24))
            // sheet title
            // TODO: set to
            .navigationTitle(sheetTitle)
            .navigationBarTitleDisplayMode(.inline)
            // toolbar for NavigationStack (for Close button)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: {
                        dismiss()
                    }) {
                        Label("Close", systemImage: "xmark")
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: {
                        editor.save()
                        dismiss()
                    }) {
                        Label("Save", systemImage: "checkmark")
                    }
                    .disabled(!editor.canSave)
                }
            }
            // load on open; focus Note field
            .task {
                editor.load()
                focusedField = .note
            }
        }
    }

    /// Filter bar chips view
    private var tagChipsView: some View {
        GlassEffectContainer(spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHGrid(rows: rows, alignment: .top, spacing: 8) {
                    if isCreatingTag {
                        // Create tag input
                        // TODO: show right-most plus button (for saving)
                        // TODO: set isCreatingTag=false when focusing Note TextInput (to collapse this)
                        // TODO: transition is instant rather than liquid glass morph between Button and TextField
                        TextField("Enter tag name...",
                                  text: $newTagText)
                        // Style
                        .lineLimit(1)
                        .font(.system(size: 12, weight: .semibold, design: .serif))
//                        .submitLabel(.done)
                        .submitLabel(.next)
                        // Style -- frame (
                        .frame(minWidth: 140)
                        // padding before glassEffect (glass wraps padded field)
                        .padding(EdgeInsets(top: 7, leading: 10, bottom: 7, trailing: 10))
                        // Share glass container
                        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
                        .glassEffectID("+ Tag", in: tagChipBarNamespace)
                        // Focus / animation
                        .animation(
                            .timingCurve(0.25, 1, 0.67, 0.93, duration: 0.15),
                            value: isCreatingTag
                        )
                        .focused($focusedField, equals: .newTag)
                        .task {
                            focusedField = .newTag
                        }
                        // Submission
                        .onSubmit(submitNewTag)

                        Button("Add Tag", systemImage: "checkmark", action: submitNewTag)
                            .labelStyle(.iconOnly)
                    } else {
                        // Create tag button
                        Button {
                            isCreatingTag = true
                        } label: {
                            HStack {
                                Image(systemName: "plus")
                                Text("Tag")
                            }
                        }
                        // Style
                        .buttonStyle(.glass)
                        .font(.system(size: 12, weight: .semibold, design: .serif))
                        // Style -- Outline border
                        // ???
                        // Share glass container
                        .glassEffectID("+ Tag", in: tagChipBarNamespace)
                        // Animation
                        .animation(
                            .timingCurve(0.25, 1, 0.67, 0.93, duration: 0.15),
                            value: isCreatingTag
                        )
                    }

                    // Existing tags
                    ForEach(visibleTags, id: \.self) { tag in
                        tagChipButtonView(tag: tag)
                    }
                }
                .padding(.horizontal, 4)
//                .onChange(of: focusedField) { _, newField in
//                    if newField == .note {
//                        isCreatingTag = false
//                    }
//                }
            }
            .shadow(color: Color.gray.opacity(0.1), radius: 5)
        }
    }

    /// Individual builder for a single filter bar button
    private func tagChipButtonView(tag: String) -> some View {
        Toggle(tag,
               isOn: $editor[tagIsSelected: tag])
        // Style
        .toggleStyle(.button)
        .buttonStyle(.glass)
        // Share glass container
        .glassEffectID(tag, in: tagChipBarNamespace)
        .animation(
            .timingCurve(0.25, 1, 0.67, 0.93, duration: 0.15),
            value: editor[tagIsSelected: tag]
        )
        .font(.system(size: 12, weight: .semibold, design: .serif))
    }

    // MARK: Functions (Private)

    /// Submit a newly entered tag + manage button/focus state
    private func submitNewTag() {
        // update editor.tags
        editor[tagIsSelected: newTagText] = true
        guard editor[tagIsSelected: newTagText] == true else {
            return
        }
        // reset state
        newTagText = ""
        focusedField = .note
        isCreatingTag = false
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
    AnnotationEditorSheetView(editor: .previewEditor())
}
