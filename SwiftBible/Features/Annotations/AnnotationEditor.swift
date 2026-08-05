//
//  AnnotationEditor.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 2026-07-25.
//

import Foundation
import OSLog

/// Underlying model binding for AnnotationEditorSheetView
///
/// Identifiable: AnnotationEditor is one editing session;
///  SwiftUI needs to distinguish "no session" from "present this specific session"
@Observable
final class AnnotationEditor: Identifiable {

    // MARK: Properties (Public)

    /// What passage reference does this annotation apply to?
    let reference: ScriptureReference
    /// Which verses are selected (what does this annotation apply to)?
    let selectedVerses: ClosedRange<Int>

    /// Sheet session's editable/entered note
    var noteText: String = ""
    /// Sheet session's selected tag set
    var tags: [String] = []

    /// Do we have any valid input that would allow us to call save()?
    var canSave: Bool {
        !noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        || tags
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .count > 0
    }

    // MARK: Properties (Private)

    private let libraryRepository: any LibraryRepository

    // Captured in load() for later use by save()
    private var existingNoteID: UUID?
    private var existingTagsID: UUID?

    /// Every tag currently used in the library
    ///
    /// (set): Only AnnotationEditor can write -- equivalent to C# {get;private set;}
    private(set) var tagVocabulary: [String] = []

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

    // MARK: Subscripts (Tags)

    subscript(tagIsSelected tag: String) -> Bool {
        get {
            // Is a tag with the same normalized form selected?
            tags.contains {
                StoredTag.normalize($0) == StoredTag.normalize(tag)
            }
        }
        set {
            // ignore if normalized value is empty
            let normalizedTag = StoredTag.normalize(tag)
            guard !normalizedTag.isEmpty else {
                return
            }

            // When adding, store the whitespace-trimmed display spelling
            let cleanedTag = tag.trimmingCharacters(in: .whitespacesAndNewlines)

            // add OR remove
            if newValue {
                // Don't append if an equivalent normalized tag already exists
                // add one cleaned display value unless already present
                if self[tagIsSelected: cleanedTag] == false {
                    tags.append(cleanedTag)
                }
            } else {
                tags.removeAll(where: { StoredTag.normalize($0) == normalizedTag })
            }
        }
    }

    // MARK: Functions

    /// Load any existing annotation(s) for this reference (a note OR a collection of tags)
    func load() {
        clearStates()
        
        do {
            // Load annotations & parse any existing tags/notes
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

            // Assign flattened tags to local vocabulary
            let flatNames = try libraryRepository.allAnnotations().flatMap { annotation -> [String] in
                guard case .tags(let names) = annotation.content else { return [] }
                return names
            }

            var displayByKey: [String: String] = [:]
            var countByKey: [String: Int] = [:]

            for name in flatNames {
                let key = StoredTag.normalize(name)
                guard !key.isEmpty else { continue }

                countByKey[key, default: 0] += 1    // count every occurrence
                if displayByKey[key] == nil {       // keep first display spelling
                    displayByKey[key] = name.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }

            tagVocabulary = countByKey
                .sorted { ($0.value, $1.key) > ($1.value, $0.key) } // most-used first
                .compactMap { displayByKey[$0.key] } // key => display name
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
        tagVocabulary = []
    }
}
