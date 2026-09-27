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
         bibleCatalogStore: BibleCatalogStore,
         libraryStore: LibraryStore) {
        // Required calculations for self.renderedPassageRuns
        let passageForAnnotation = libraryStore.passage(for: annotation)
        let verseRange = RenderedVerseRange(range: annotation.verseRange)
        let renderedPassageRunsForAnnotation = passageForAnnotation?.renderedPassage.runs(for: verseRange)

        // Done -- assign and leave
        self.annotation = annotation
        self.renderedPassageRuns = renderedPassageRunsForAnnotation
        self.passageLabel = bibleCatalogStore.friendlyPassageName(for: annotation)
        self.translationLabel = bibleCatalogStore.translation(for: annotation.translationID)?.abbreviation ?? ""
    }
}
