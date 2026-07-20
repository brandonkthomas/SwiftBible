//
//  VerseAnnotation.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 7/9/26.
//

import Foundation

/// User saved something (highlight, note, etc) for this exact verse range
nonisolated struct VerseAnnotation: Identifiable, Equatable {

    // MARK: Properties

    let id: UUID
    let translationID: Translation.ID
    let bookCode: String
    let chapter: Int
    let startVerse: Int
    let endVerse: Int?

    var content: AnnotationContent

    let createdAt: Date
    var updatedAt: Date?

    // MARK: Properties (Computed)

    var highlightColor: VerseAnnotationHighlightColor? {
        if case .highlight(let color) = content {
            return color
        }

        return nil
    }

    // MARK: Init
    
    /// Direct-field-reference non-failable init that bypasses field validation;
    /// ONLY used by `SwiftDataLibraryRepository`
    init(id: UUID,
         translationID: Translation.ID,
         bookCode: String,
         chapter: Int,
         startVerse: Int,
         endVerse: Int?,
         
         content: AnnotationContent,

         createdAt: Date,
         updatedAt: Date? = nil) {
        self.id = id
        self.translationID = translationID
        self.bookCode = bookCode
        self.chapter = chapter
        self.startVerse = startVerse
        self.endVerse = endVerse
        
        self.content = content
        
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// Init will fail + return nil if none of no real content is provided (i.e. non-empty).
    init?(
        id: UUID = UUID(),
        reference: ScriptureReference,
        selectedVerses: ClosedRange<Int>,

        content: AnnotationContent,

        createdAt: Date = .now
    ) {
        // Ensure at least 1 non-empty storage value is provided
        guard content.isMeaningful else { return nil }

        self.id = id
        self.translationID = reference.translationID
        self.bookCode = reference.bookCode
        self.chapter = reference.chapter
        self.startVerse = selectedVerses.lowerBound
        self.endVerse = selectedVerses.count == 1 ? nil : selectedVerses.upperBound

        self.content = content

        self.createdAt = createdAt
        self.updatedAt = nil
    }
}

nonisolated enum AnnotationContent: Equatable {
    case highlight(VerseAnnotationHighlightColor)
    case note(String)
    case tags([String])

    var type: AnnotationContentType {
        switch self {
        case .highlight: return .highlight
        case .note: return .note
        case .tags: return .tags
        }
    }

    var isMeaningful: Bool {
        switch self {
        case .highlight:
            return true
        case .note(let text):
            return !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .tags(let names):
            return names.contains { name in
                !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
        }
    }
}

enum AnnotationContentType {
    case highlight
    case note
    case tags
}
