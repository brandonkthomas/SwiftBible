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

    @FocusState private var isNoteFocused: Bool

    private var isCollapsed: Bool { isNoteFocused }

    @Namespace private var tagChipBarNamespace

    // MARK: Properties (Computed)

    private var sheetTitle: String {
        //        guard let bookAndChapter = passage.referenceBookAndChapterDisplayName else {
        return "Notes & Tags"
        //        }
        //        return "\(bookAndChapter):\(verseRange.displayText)"
    }

    private var rows: [GridItem] {
        isCollapsed
        ? [GridItem(.fixed(36))]
        : [GridItem(.fixed(36)), GridItem(.fixed(36))]
    }

    ///
    private var visibleTags: [String] {
        isCollapsed ? editor.tags : ["tag1", "tag2"] // tagVocabulary
    }

    // MARK: Views

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                // Tags section
                Label("TAGS", systemImage: "tag")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                tagChipsView

                Divider()

                // Note section
                Label("NOTE", systemImage: "text.alignleft")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                TextField("Write a note about this passage…",
                          text: $editor.noteText,
                          axis: .vertical)
                .onSubmit {
                    // ...
                }
                .lineLimit(1...8)
                // padding before glassEffect (glass wraps padded field)
                .padding()
                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
                .focused($isNoteFocused)
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
            // load on open
            .task {
                editor.load()
            }
        }
    }

    /// Filter bar chips view
    private var tagChipsView: some View {
        GlassEffectContainer(spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHGrid(rows: rows, alignment: .top, spacing: 8) {
                    ForEach(visibleTags, id: \.self) { tag in
                        tagChipButtonView(tag: tag)
                    }
                }
                .padding(.horizontal, 4)
            }
            .shadow(color: Color.gray.opacity(0.1), radius: 5)
        }
    }

    /// Individual builder for a single filter bar button
    private func tagChipButtonView(tag: String) -> some View {
        Toggle(tag,
               isOn: tagBinding(for: tag))
        .toggleStyle(.button)
        .buttonStyle(.glass)
        .glassEffectID(tag, in: tagChipBarNamespace)
        .animation(
            .timingCurve(0.25, 1, 0.67, 0.93, duration: 0.15),
            value: editor.tags.contains(tag)
        )
        .font(.system(size: 12, weight: .semibold))
    }

    private func tagBinding(for tag: String) -> Binding<Bool> {
        return Binding(get: {
            editor.tags.contains(tag)
        }, set: {
            if $0 {
                editor.tags.append(tag)
            } else {
                editor.tags.removeAll(where: { $0 == tag })
            }
        })
    }
}

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
