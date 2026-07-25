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

    private func clearStates() {
        noteText = ""
        tags = []
        existingNoteID = nil
        existingTagsID = nil
    }
}
