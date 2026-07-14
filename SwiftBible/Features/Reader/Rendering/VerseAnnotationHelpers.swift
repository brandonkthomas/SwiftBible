//
//  VerseAnnotationHelpers.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 2026-07-13.
//

import Foundation

enum VerseAnnotationHelpers { // caseless enum as pseudo-namespace

    /// For a given passage reference, sort + return all annotation highlight colors for that specific reference
    static func getPassageHighlightColors(
        for annotations: [VerseAnnotation],
        reference: ScriptureReference
    ) -> [Int: VerseAnnotationHighlightColor] {
        var result: [Int: VerseAnnotationHighlightColor] = [:]

        // 1. filter to same translation/book/chapter where highlight exists
        let matchingAnnotations = annotations
            .filter { annotation in
                // passages match
                annotation.translationID == reference.translationID
                && annotation.bookCode == reference.bookCode
                && annotation.chapter == reference.chapter
                // highlight exists
                && annotation.highlightColor != nil
            }
            .sorted { lhs, rhs in
                // Oldest first so newest overwrites it later
                (lhs.updatedAt ?? lhs.createdAt) < (rhs.updatedAt ?? rhs.createdAt)
            }

        // 2. add matching results to final list
        for annotation in matchingAnnotations {
            // we already filtered this above; unwrap
            guard let color = annotation.highlightColor else {
                continue
            }

            let annotationStart = annotation.startVerse
            let annotationEnd = annotation.endVerse ?? annotation.startVerse

            for verse in annotationStart...annotationEnd {
                guard annotationStart <= annotationEnd else { continue }
                result[verse] = color
            }
        }

        return result
    }
}
