//
//  SwiftDataLibraryRepository.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 2026-07-12.
//

import Foundation
import SwiftData

final class SwiftDataLibraryRepository: LibraryRepository {
    
    // MARK: Properties
    
    let container: ModelContainer
    let context: ModelContext
    
    init(modelContainer: ModelContainer) {
        self.container = modelContainer
        self.context = modelContainer.mainContext
    }
    
    // MARK: Functions (Implementations)
    
    /// Map VerseAnnotation => StoredVerseAnnotation, insert into self.context, & save self.context
    func save(_ annotation: VerseAnnotation) throws {
        let storageContent = storageContent(for: annotation.content)
        let resolvedTags = try resolveTags(storageContent.tags)
        
        // Insert/update branch
        if let existingAnnotation = try fetch(by: annotation.id) {
            // We found an existing VerseAnnotation w/ this ID; update its mutable fields
            // directly (SwiftData tracks mutations for @Model)
            existingAnnotation.highlightColor = storageContent.highlightColor
            existingAnnotation.tags = resolvedTags
            existingAnnotation.note = storageContent.note
            existingAnnotation.updatedAt = .now
        } else {
            // There's no existing VerseAnnotation w/ this ID; insert a new one
            let storedVerseAnnotation = StoredVerseAnnotation(id: annotation.id,
                                                              translationID: annotation.translationID,
                                                              bookCode: annotation.bookCode,
                                                              chapter: annotation.chapter,
                                                              startVerse: annotation.startVerse,
                                                              endVerse: annotation.endVerse,
                                                              highlightColor: storageContent.highlightColor,
                                                              note: storageContent.note,
                                                              createdAt: annotation.createdAt,
                                                              updatedAt: annotation.updatedAt)
            storedVerseAnnotation.tags = resolvedTags
            
            // Stage the insertion
            context.insert(storedVerseAnnotation)
        }
    
        // Now we can try to persist the changes
        try context.save()
    }
    
    /// Return all annotations for a specfiic reference
    func annotations(for reference: ScriptureReference) throws -> [VerseAnnotation] {
        let translationID = reference.translationID
        let bookCode = reference.bookCode
        let chapter = reference.chapter
        
        // Build a type-safe query expression -- this is translated into a store query (SQLite);
        //  Swift does NOT run this over in-memory objects
        let predicate = #Predicate<StoredVerseAnnotation> { annotation in
            annotation.translationID == translationID
            && annotation.bookCode == bookCode
            && annotation.chapter == chapter
        }
        
        // Now use the Predicate as the FetchDescriptor definition & try to search
        let fetchDescriptor = FetchDescriptor(predicate: predicate)
        let annotations: [StoredVerseAnnotation] = try context.fetch(fetchDescriptor)
        
        // Map + return results
        let mappedAnnotations: [VerseAnnotation] = annotations.compactMap { storedAnnotation in
            guard let content = annotationContent(from: storedAnnotation) else {
                return nil
            }

            return VerseAnnotation.init(
                id: storedAnnotation.id,
                translationID: storedAnnotation.translationID,
                bookCode: storedAnnotation.bookCode,
                chapter: storedAnnotation.chapter,
                startVerse: storedAnnotation.startVerse,
                endVerse: storedAnnotation.endVerse,
                content: content,
                createdAt: storedAnnotation.createdAt,
                updatedAt: storedAnnotation.updatedAt
            )
        }
        
        return mappedAnnotations
    }
    
    /// Delete a StoredVerseAnnotation by ID (if found)
    func delete(_ id: UUID) throws {
        let annotation = try fetch(by: id)
        
        if let annotation {
            context.delete(annotation)
        }
        
        try context.save()
    }
    
    // MARK: Functions (Private)
    
    private func storageContent(for content: AnnotationContent) -> (highlightColor: VerseAnnotationHighlightColor?, note: String?, tags: [String]?) {
        switch content {
        case .highlight(let color):
            return (color, nil, nil)
        case .note(let note):
            return (nil, note, nil)
        case .tags(let tags):
            return (nil, nil, tags)
        }
    }

    /// Precedence: highlight -> note -> tags (only one of these will ever exist per annotation unless something went wrong)
    private func annotationContent(from storedAnnotation: StoredVerseAnnotation) -> AnnotationContent? {
        if let highlightColor = storedAnnotation.highlightColor {
            return .highlight(highlightColor)
        }

        if let note = storedAnnotation.note,
           !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return .note(note)
        }

        let tagNames = storedAnnotation.tags?.map(\.displayName) ?? []
        guard tagNames.contains(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
            return nil
        }

        return .tags(tagNames)
    }

    /// Find any matching StoredTag for a given list of tag names
    ///
    /// Move this to StoredTag if it's ever used outside this file in the future
    private func resolveTags(_ names: [String]?) throws -> [StoredTag] {
        guard let names else {
            return []
        }
        
        // normalize all names before continuing
        var displayByNormalized: [(String, String)] = [] // normalized, original
        
        for original in names {
            let normalized = StoredTag.normalize(original)
            let originalTrimmed = original.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalized.isEmpty else {
                continue
            }
            displayByNormalized.append((normalized, originalTrimmed))
        }
        
        let displayByNormalizedUnique = Dictionary(displayByNormalized,
                                                   uniquingKeysWith: { first, _ in first })
        let uniqueNormalized = Array(displayByNormalizedUnique.keys)
        
        // short circuit opportunity
        guard !uniqueNormalized.isEmpty else {
            return []
        }
        
        // search predicate for any unique normalized tag that already exists
        let predicate = #Predicate<StoredTag> { tag in
            uniqueNormalized.contains(tag.normalizedName)
        }
        
        // Now use the Predicate as the FetchDescriptor definition & try to search
        let fetchDescriptor = FetchDescriptor(predicate: predicate)
        
        let existingTags: [StoredTag] = try context.fetch(fetchDescriptor)
        
        // track any normalized names already in the store
        let existingKeys = Set(existingTags.map(\.normalizedName))
        
        // create tags that dont exist yet
        // we could insert a new tag into an existing annotation;
        // so need to explicitly insert tags here
        var createdTags: [StoredTag] = []
                
        for (normalized, display) in displayByNormalizedUnique where !existingKeys.contains(normalized) {
            let tag = StoredTag.init(id: UUID(),
                                     displayName: display,
                                     normalizedName: normalized)
            context.insert(tag)
            createdTags.append(tag)
        }
        
        // don't context.save() here; callers will handle
        return existingTags + createdTags
    }
    
    private func fetch(by id: UUID) throws -> StoredVerseAnnotation? {
        // First, check for an existing record w/ this ID
        // Build a type-safe query expression -- this is translated into a store query (SQLite);
        //  Swift does NOT run this over in-memory objects
        let predicate = #Predicate<StoredVerseAnnotation> { annotation in
            annotation.id == id
        }
        
        // Now use the Predicate as the FetchDescriptor definition & try to search
        var fetchDescriptor = FetchDescriptor(predicate: predicate)
        fetchDescriptor.fetchLimit = 1 // stop at 1st match; IDs are unique
        
        let annotations: [StoredVerseAnnotation] = try context.fetch(fetchDescriptor)
        
        return annotations.first // can be nil if not found
    }
}
