//
//  LibraryFilter.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 2026-07-19.
//

import Foundation

struct LibraryFilter: Equatable {

    // MARK: Properties

    var bookCode: String?
    var translationID: Translation.ID?
    var contentType: AnnotationContentType?
    var highlightColor: VerseAnnotationHighlightColor?
    var tag: String?

    // MARK: Properties (Computed)

    var isAnyFilterActive: Bool {
        self != LibraryFilter()
    }

    var isBookCodeFilterActive: Bool {
        bookCode != nil
    }

    var isTranslationIdFilterActive: Bool {
        translationID != nil
    }

    var isContentTypeFilterActive: Bool {
        contentType != nil
    }

    var isNoteFilterActive: Bool {
        contentType == .note
    }

    var isHighlightColorFilterActive: Bool {
        highlightColor != nil
    }

    var isTagFilterActive: Bool {
        tag != nil
    }

    // MARK: Functions

    /// Does the requested annotation match our filter?
    func matches(_ annotation: VerseAnnotation) -> Bool {
        if let bookCode, annotation.bookCode != bookCode { return false }
        if let translationID, annotation.translationID != translationID { return false }
        if let contentType, annotation.content.type != contentType { return false }
        if let highlightColor {
            guard case .highlight(let color) = annotation.content, color == highlightColor else { return false }
        }
        if let tag {
            guard case .tags(let names) = annotation.content, names.contains(tag) else { return false }
        }
        return true
    }

    /// Reset all applied filters
    mutating func clearAllFilters() {
        bookCode = nil
        translationID = nil
        contentType = nil
        highlightColor = nil
        tag = nil
    }
}
