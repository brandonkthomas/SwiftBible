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

    /// For a given passage reference, return all verse numbers covered by any of a passage's
    /// note/tag annotations (highlights excluded)
    static func getPassageVersesWithTextAnnotations(
        for annotations: [VerseAnnotation],
        reference: ScriptureReference
    ) -> Set<Int> {
        var verses: Set<Int> = []

        for annotation in annotations where isTextAnnotation(annotation, in: reference) {
            verses.formUnion(annotation.verseRange)
        }

        return verses
    }

    /// For a given passage reference + verse number, return the note/tag annotation
    /// covering that verse (highlights excluded)
    ///
    /// If several overlap, the newest wins (same rule as getPassageHighlightColors())
    static func getTextAnnotation(
        for annotations: [VerseAnnotation],
        reference: ScriptureReference,
        verse: Int
    ) -> VerseAnnotation? {
        annotations
            .filter { isTextAnnotation($0, in: reference) && $0.verseRange.contains(verse) }
            .max { lhs, rhs in
                (lhs.updatedAt ?? lhs.createdAt) < (rhs.updatedAt ?? rhs.createdAt)
            }
    }

    // MARK: Functions (Private)

    /// Is this a meaningful note/tag annotation in the reference's translation/book/chapter?
    ///
    /// Single source of truth for getPassageVersesWithTextAnnotations() (which verses draw a
    /// bookmark) and getTextAnnotation() (what a tapped bookmark opens), so every drawn
    /// bookmark resolves to an annotation
    private static func isTextAnnotation(_ annotation: VerseAnnotation,
                                         in reference: ScriptureReference) -> Bool {
        annotation.translationID == reference.translationID
        && annotation.bookCode == reference.bookCode
        && annotation.chapter == reference.chapter
        && (annotation.content.type == .note || annotation.content.type == .tags)
        && annotation.content.isMeaningful // sanity check
    }
}
