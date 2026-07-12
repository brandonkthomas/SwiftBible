//
//  StoredVerseAnnotation.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 2026-07-11.
//

import Foundation
import SwiftData

/// Sibling CloudKit storage file for `VerseAnnotation`
///
/// `VerseAnnotation` is unaware of this file; only `LibraryRepository` knows of both
/// (repo to models, never inverse)
///
/// Final class over struct (this needs to be a ref type bound to ModelContext).
/// \@Model is essentially a C# EF Core table-mapped entity;
/// it rewrites the class at compiletime to track identity/mutations/accessors/registrations.
///
/// \@Attribute(.unique) macro not needed here (SwiftData) because CloudKit has no field
/// uniqueness constraint
///
/// final: we dont need this Model to ever be subclassed
///
/// Defaults are required by CloudKit for non-optionals; else they're rejected...
/// id/etc uses a default so that CloudKit can materialize populated records; no optional app-facing
/// paths are ever exposed (so SwiftBible cannot use defaults)
@Model
final class StoredVerseAnnotation {
    var id: UUID = UUID()
    
    var translationID: Int = 0
    var bookCode: String = ""
    var chapter: Int = 0
    var startVerse: Int = 0
    var endVerse: Int?
    
    var highlightColor: VerseAnnotationHighlightColor?
    var note: String?
    /// 1 annotation:M tags
    ///
    /// Inform SwiftData of the linked (inverse) relationship property.
    /// Annotations do not own their tags; nullify on delete.
    @Relationship(deleteRule: .nullify, inverse: \StoredTag.annotations)
    var tags: [StoredTag]?
    
    var createdAt: Date = Date.now
    var updatedAt: Date?
    
    init(
        id: UUID,
        translationID: Int,
        bookCode: String,
        chapter: Int,
        startVerse: Int,
        endVerse: Int? = nil,
        highlightColor: VerseAnnotationHighlightColor? = nil,
        note: String? = nil,
        createdAt: Date,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.translationID = translationID
        self.bookCode = bookCode
        self.chapter = chapter
        self.startVerse = startVerse
        self.endVerse = endVerse
        self.highlightColor = highlightColor
        self.note = note
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
