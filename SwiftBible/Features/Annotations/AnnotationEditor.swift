//
//  AnnotationEditor.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 2026-07-25.
//

import Foundation

/// Underlying model binding for AnnotationEditorSheetView
@Observable
final class AnnotationEditor {
    let reference: ScriptureReference
    let selectedVerses: ClosedRange<Int>
    let libraryRepository: LibraryRepository

    private var existingNoteID: UUID?
    private var existingTagsID: UUID?

    var noteText: String = ""
    var tags: [String] = []

    init(reference: ScriptureReference,
         selectedVerses: ClosedRange<Int>,
         libraryRepository: LibraryRepository) {
        self.reference = reference
        self.selectedVerses = selectedVerses
        self.libraryRepository = libraryRepository
    }

    /// Load any existing annotation(s) for this reference (a note OR a collection of tags)
    func load() {
        do {
            let annotations = try libraryRepository.annotations(for: reference)

            guard let existingTagAnnotation = annotations.first(where: { $0.content.type == .tags && $0.verseRange == selectedVerses }),
                  let existingNoteAnnotation = annotations.first(where: { $0.content.type == .note && $0.verseRange == selectedVerses }) else {
                return
            }

            // Existing note
            self.existingNoteID = existingNoteAnnotation.id
            if case .note(let text) = existingNoteAnnotation.content {
                self.noteText = text
            }

            // Existing tags
            self.existingTagsID = existingTagAnnotation.id
            if case .tags(let tagNames) = existingTagAnnotation.content {
                self.tags = tagNames
            }
        } catch {
            // ...?
        }
    }
}
