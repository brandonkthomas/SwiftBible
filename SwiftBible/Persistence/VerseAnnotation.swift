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

    var highlightColor: String? // TODO: convert to enum w/ available colors
    var note: String?
    var tags: [String]?

    let createdAt: Date
    var updatedAt: Date?

    // MARK: Init

    /// Init will fail + return nil if none of highlight/note/tag are provided.
    init?(
        id: UUID = UUID(),
        reference: ScriptureReference,
        selectedVerses: ClosedRange<Int>,

        highlightColor: String?,
        note: String?,
        tags: [String]?,

        createdAt: Date = .now
    ) {
        // Ensure at least 1 non-empty storage value is provided
        guard Self.hasText(highlightColor)
                || Self.hasText(note)
                || tags?.contains(where: { Self.hasText($0) }) == true
        else {
            return nil
        }

        self.id = id
        self.translationID = reference.translationID
        self.bookCode = reference.bookCode
        self.chapter = reference.chapter
        self.startVerse = selectedVerses.lowerBound
        self.endVerse = selectedVerses.count == 1 ? nil : selectedVerses.upperBound

        self.highlightColor = highlightColor
        self.note = note
        self.tags = tags

        self.createdAt = createdAt
        self.updatedAt = nil
    }

    // MARK: Functions (Private)

    private static func hasText(_ value: String?) -> Bool {
        guard let value else {
            return false
        }

        return !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
