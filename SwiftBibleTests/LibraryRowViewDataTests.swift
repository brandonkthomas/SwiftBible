//
//  LibraryRowViewDataTests.swift
//  SwiftBibleTests
//
//  Created by Brandon Thomas on 2026-09-24.
//

import Foundation
import Testing
@testable import SwiftBible

@MainActor
struct LibraryRowViewDataTests {

    /// When the catalog has no matching translation/book, labels fall back to the
    /// annotation's raw identifiers instead of a display name
    @Test func missingCatalogMetadataFallsBackToRawIdentifiers() throws {
        // catalogStore never loads translations/books, so both lookups return nil
        let catalogStore = BibleCatalogStore(repository: FakeBibleRepository())
        let libraryStore = makeLibraryStore()
        let annotation = makeAnnotation(translationID: 9999,
                                        bookCode: "XYZ",
                                        startVerse: 1)

        let viewData = LibraryRowViewData(annotation: annotation,
                                          bibleCatalogStore: catalogStore,
                                          libraryStore: libraryStore)

        #expect(viewData.passageLabel == "XYZ 1:1")
        #expect(viewData.translationLabel == "")
    }

    /// A multi-verse annotation's label shows the range; a single-verse one shows one number
    @Test func passageLabelShowsRangeOrSingleVerse() throws {
        let catalogStore = BibleCatalogStore(repository: FakeBibleRepository())
        let libraryStore = makeLibraryStore()
        let multiVerseAnnotation = makeAnnotation(startVerse: 1, endVerse: 3)
        let singleVerseAnnotation = makeAnnotation(startVerse: 5, endVerse: nil)

        let multiVerseViewData = LibraryRowViewData(annotation: multiVerseAnnotation,
                                                     bibleCatalogStore: catalogStore,
                                                     libraryStore: libraryStore)
        let singleVerseViewData = LibraryRowViewData(annotation: singleVerseAnnotation,
                                                      bibleCatalogStore: catalogStore,
                                                      libraryStore: libraryStore)

        #expect(multiVerseViewData.passageLabel == "GEN 1:1–3")
        #expect(singleVerseViewData.passageLabel == "GEN 1:5")
    }

    /// If the annotation's chapter hasn't been loaded into the LibraryStore yet,
    /// there are no runs to render
    @Test func unloadedChapterProducesNilRuns() throws {
        let catalogStore = BibleCatalogStore(repository: FakeBibleRepository())
        let libraryStore = makeLibraryStore()
        let annotation = makeAnnotation(startVerse: 1)

        // deliberately not calling libraryStore.loadPassage(for:) here

        let viewData = LibraryRowViewData(annotation: annotation,
                                          bibleCatalogStore: catalogStore,
                                          libraryStore: libraryStore)

        #expect(viewData.renderedPassageRuns == nil)
    }

    /// Once the annotation's chapter has been saved + loaded, its verse has real runs to render
    @Test func loadedChapterProducesNonEmptyRuns() async throws {
        let catalogStore = BibleCatalogStore(repository: FakeBibleRepository())
        let libraryRepository = InMemoryLibraryRepository()
        let libraryStore = makeLibraryStore(libraryRepository: libraryRepository)
        // translationID 1234 + GEN 1 matches FakeBibleRepository.defaultPassages
        let annotation = makeAnnotation(startVerse: 1)

        try libraryRepository.save(annotation)
        libraryStore.load()
        await libraryStore.loadPassage(for: annotation)

        let viewData = LibraryRowViewData(annotation: annotation,
                                          bibleCatalogStore: catalogStore,
                                          libraryStore: libraryStore)

        let runs = try #require(viewData.renderedPassageRuns)
        #expect(!runs.isEmpty)
    }

    // MARK: Functions (Private Helpers)

    private func makeLibraryStore(
        libraryRepository: any LibraryRepository = InMemoryLibraryRepository()
    ) -> LibraryStore {
        LibraryStore(libraryRepository: libraryRepository,
                     passageStore: BiblePassageStore(repository: FakeBibleRepository(),
                                                     passageCache: InMemoryPassageCache()))
    }

    private func makeAnnotation(
        translationID: Translation.ID = 1234,
        bookCode: String = "GEN",
        chapter: Int = 1,
        startVerse: Int,
        endVerse: Int? = nil,
        content: AnnotationContent = .note("Test note")
    ) -> VerseAnnotation {
        VerseAnnotation(id: UUID(),
                        translationID: translationID,
                        bookCode: bookCode,
                        chapter: chapter,
                        startVerse: startVerse,
                        endVerse: endVerse,
                        content: content,
                        createdAt: .now)
    }
}
