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
        // Resolve tags
        let resolvedTags = try resolveTags(annotation.tags)
        
        // Insert/update branch
        if let existingAnnotation = try fetch(by: annotation.id) {
            // We found an existing VerseAnnotation w/ this ID; update its mutable fields
            // directly (SwiftData tracks mutations for @Model)
            existingAnnotation.highlightColor = annotation.highlightColor
            existingAnnotation.tags = resolvedTags
            existingAnnotation.note = annotation.note
            existingAnnotation.updatedAt = .now
        } else {
            // There's no existing VerseAnnotation w/ this ID; insert a new one
            let storedVerseAnnotation = StoredVerseAnnotation(id: annotation.id,
                                                              translationID: annotation.translationID,
                                                              bookCode: annotation.bookCode,
                                                              chapter: annotation.chapter,
                                                              startVerse: annotation.startVerse,
                                                              endVerse: annotation.endVerse,
                                                              highlightColor: annotation.highlightColor,
                                                              note: annotation.note,
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
        let mappedAnnotations: [VerseAnnotation] = annotations.map {
            VerseAnnotation.init(
                id: $0.id,
                translationID: $0.translationID,
                bookCode: $0.bookCode,
                chapter: $0.chapter,
                startVerse: $0.startVerse,
                endVerse: $0.endVerse,
                highlightColor: $0.highlightColor,
                note: $0.note,
                tags: $0.tags?.map(\.displayName),
                createdAt: $0.createdAt,
                updatedAt: $0.updatedAt
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
