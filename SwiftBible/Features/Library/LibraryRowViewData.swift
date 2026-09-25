//
//  LibraryRowViewData.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 2026-09-24.
//

import Foundation

/// All information required by LibraryRowView (consolidated for ease of construction by cache/etc)
struct LibraryRowViewData {
    /// Annotation which this row represents
    let annotation: VerseAnnotation

    /// Runs for this passage (used for rendering actual verse using PassageTextRenderer)
    let renderedPassageRuns: [RenderedPassageRun]?

    /// Label for the passage (i.e. "Genesis 1:1-2")
    let passageLabel: String

    /// Label for the translation (i.e. "NIV")
    let translationLabel: String

    init(annotation: VerseAnnotation,
         catalogStore: BibleCatalogStore,
         libraryStore: LibraryStore) {
        // Translation
        let translation = catalogStore.translation(for: annotation.translationID)

        // Book
        let book = catalogStore.book(for: annotation.translationID,
                                     bookCode: annotation.bookCode)

        // Verse range
        let upperBoundSameAsLowerBound = annotation.verseRange.upperBound == annotation.verseRange.lowerBound
        let endVerseCalculated = upperBoundSameAsLowerBound ? nil : annotation.verseRange.upperBound

        let verseRange = RenderedVerseRange(startVerse: annotation.verseRange.lowerBound,
                                            endVerse: endVerseCalculated)

        // Passage label
        let passageLabel = "\(book?.displayName ?? annotation.bookCode) \(annotation.chapter):\(verseRange.displayText)"

        // RenderedPassageRuns
        let passageForAnnotation = libraryStore.passage(for: annotation)

        let renderedPassageRunsForAnnotation = passageForAnnotation?.renderedPassage.runs(for: verseRange)

        // Done -- assign and leave
        self.annotation = annotation
        self.renderedPassageRuns = renderedPassageRunsForAnnotation
        self.passageLabel = passageLabel
        self.translationLabel = translation?.abbreviation ?? annotation.translationID.description
    }
}
