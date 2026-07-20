//
//  LibraryFilter.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 2026-07-19.
//

import Foundation

struct LibraryFilter: Equatable {
    var bookCode: String?
    var translationID: Translation.ID?
    var contentType: AnnotationContentType?
    var highlightColor: VerseAnnotationHighlightColor?
    var tag: String?

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
}
