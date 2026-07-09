//
//  VerseAnnotation.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 7/9/26.
//

import Foundation

/// User saved something (highlight, note, etc) for this exact verse range
struct VerseAnnotation: Identifiable {

    // MARK: Properties

    let id: UUID
    let translationID: Translation.ID
    let bookCode: String
    let chapter: Int
    let startVerse: Int
    let endVerse: Int?

    var highlightColor: String? // TODO: convert to enum w/ available colors
    var note: String?
    var tag: String?

    let createdAt: Date
    var updatedAt: Date?

    // MARK: Init

    init(
        id: UUID = UUID(),
        reference: ScriptureReference,
        selectedVerses: ClosedRange<Int>,

        highlightColor: String?,
        note: String?,
        tag: String?,
        
        createdAt: Date = .now
    ) {
        self.id = id
        self.translationID = reference.translationID
        self.bookCode = reference.bookCode
        self.chapter = reference.chapter
        self.startVerse = selectedVerses.lowerBound
        self.endVerse = selectedVerses.count == 1 ? nil : selectedVerses.upperBound

        self.highlightColor = highlightColor
        self.note = note
        self.tag = tag

        self.createdAt = createdAt
        self.updatedAt = nil
    }
}
