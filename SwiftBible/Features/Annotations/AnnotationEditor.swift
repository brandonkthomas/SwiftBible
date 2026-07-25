//
//  AnnotationEditor.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 2026-07-25.
//

import Foundation
import OSLog

/// Underlying model binding for AnnotationEditorSheetView
@Observable
final class AnnotationEditor {

    // MARK: Properties (Public)

    let reference: ScriptureReference
    let selectedVerses: ClosedRange<Int>

    var noteText: String = ""
    var tags: [String] = []

    // MARK: Properties (Private)

    private let libraryRepository: any LibraryRepository

    // Captured in load() for later use by save()
    private var existingNoteID: UUID?
    private var existingTagsID: UUID?

    /// OS Logging
    private static let logger = Logger(subsystem: "SwiftBible", category: "AnnotationEditor")

    // MARK: Init

    init(reference: ScriptureReference,
         selectedVerses: ClosedRange<Int>,
         libraryRepository: LibraryRepository) {
        self.reference = reference
        self.selectedVerses = selectedVerses
        self.libraryRepository = libraryRepository
    }

    // MARK: Functions

    /// Load any existing annotation(s) for this reference (a note OR a collection of tags)
    func load() {
        clearStates()
        
        do {
            let annotations = try libraryRepository.annotations(for: reference)
            let rangeAnnotations = annotations.filter { $0.verseRange == selectedVerses }

            for annotation in rangeAnnotations {
                switch annotation.content {
                // Existing note
                case .note(let text):
                    noteText = text
                    existingNoteID = annotation.id
                // Existing tags
                case .tags(let names):
                    tags = names
                    existingTagsID = annotation.id
                case .highlight:
                    break
                }
            }
        } catch {
            Self.logger.error("Unable to load annotations: \(error.localizedDescription)")
            return
        }
    }

    /// Save current tags/note to repository.
    ///
    /// Clean data, upsert by ID, update AnnotationEditor private IDs
    ///
    /// current             existing id    action
    /// meaningful      nil                  create (new UUID)
    /// meaningful      set                 update (reuse that id)
    /// empty              set                 delete
    /// empty              nil                   nothing
    func save() {
        // Note
        let cleanedNote = noteText.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            // for ID: update existing else insert new
            let annotationNote = VerseAnnotation(id: existingNoteID ?? UUID(),
                                             reference: reference,
                                             selectedVerses: selectedVerses,
                                             content: .note(cleanedNote))

            // annotation.content.isMeaningful will always be true at this point
            // (since VerseAnnotation.init() would otherwise fail)
            if let annotationNote {
                // Only save if we have valid data
                // Else try to delete if a record exists
                try libraryRepository.save(annotationNote)
                self.existingNoteID = annotationNote.id
            } else if let existingNoteID {
                try libraryRepository.delete(existingNoteID)
                self.existingNoteID = nil
            }
        } catch {
            Self.logger.error("Unable to save note: \(error.localizedDescription)")
        }

        // Tags
        let cleanedTags = tags
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        do {
            // for ID: update existing else insert new
            let annotationTags = VerseAnnotation(id: existingTagsID ?? UUID(),
                                             reference: reference,
                                             selectedVerses: selectedVerses,
                                             content: .tags(cleanedTags))
            // annotation.content.isMeaningful will always be true at this point
            // (since VerseAnnotation.init() would otherwise fail)
            if let annotationTags {
                // Only save if we have valid data
                // Else try to delete if a record exists
                try libraryRepository.save(annotationTags)
                self.existingTagsID = annotationTags.id
            } else if let existingTagsID {
                try libraryRepository.delete(existingTagsID)
                self.existingTagsID = nil
            }
        } catch {
            Self.logger.error("Unable to save tags: \(error.localizedDescription)")
        }
    }

    // MARK: Functions (Private)

    private func clearStates() {
        noteText = ""
        tags = []
        existingNoteID = nil
        existingTagsID = nil
    }
}
