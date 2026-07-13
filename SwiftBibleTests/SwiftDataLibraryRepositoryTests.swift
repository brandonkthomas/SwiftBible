//
//  SwiftDataLibraryRepositoryTests.swift
//  SwiftBibleTests
//
//  Created by Brandon Thomas on 2026-07-12.
//

import Foundation
import SwiftData
import Testing
@testable import SwiftBible

@MainActor
struct SwiftDataLibraryRepositoryTests {

    /// save then annotations(for:) returns it (with tags mapped back to strings)
    @Test func saveReturnsAnnotationWithTags() throws {
        let repository = try buildRepository()
        let reference = try buildReference()
        let verseRange = try #require(reference.verseRange)
        let annotation = try #require(VerseAnnotation(reference: reference,
                                                      selectedVerses: verseRange,
                                                      highlightColor: .yellow,
                                                      note: "Note content",
                                                      tags: ["memory"]))

        try repository.save(annotation)
        let results = try repository.annotations(for: reference)

        #expect(results == [annotation])
    }

    /// Upsert: save the same id twice with a different color returns one updated annotation
    @Test func savingSameIDUpdatesExistingAnnotation() throws {
        let repository = try buildRepository()
        let reference = try buildReference()
        let verseRange = try #require(reference.verseRange)
        let id = UUID()
        let createdAt = Date()

        let annotation = try #require(VerseAnnotation(id: id,
                                                      reference: reference,
                                                      selectedVerses: verseRange,
                                                      highlightColor: .yellow,
                                                      note: "Original note",
                                                      tags: ["memory"],
                                                      createdAt: createdAt))
        let updatedAnnotation = VerseAnnotation(id: id,
                                                translationID: reference.translationID,
                                                bookCode: reference.bookCode,
                                                chapter: reference.chapter,
                                                startVerse: verseRange.lowerBound,
                                                endVerse: verseRange.upperBound,
                                                highlightColor: .blue,
                                                note: "Updated note",
                                                tags: ["study"],
                                                createdAt: createdAt)

        try repository.save(annotation)
        try repository.save(updatedAnnotation)
        let results = try repository.annotations(for: reference)
        let result = try #require(results.first)

        #expect(results.count == 1)
        #expect(result.id == id)
        #expect(result.highlightColor == .blue)
        #expect(result.note == "Updated note")
        #expect(result.tags == ["study"])
        #expect(result.updatedAt != nil)
    }

    /// Tag reuse: shared tag names collapse to one StoredTag row across annotations
    @Test func sharedTagNamesReuseStoredTag() throws {
        let modelContainer = try buildModelContainer()
        let repository = SwiftDataLibraryRepository(modelContainer: modelContainer)
        let reference1 = try buildReference(chapter: 1)
        let verseRange1 = try #require(reference1.verseRange)
        let reference2 = try buildReference(chapter: 2)
        let verseRange2 = try #require(reference2.verseRange)
        let annotation1 = try #require(VerseAnnotation(reference: reference1,
                                                       selectedVerses: verseRange1,
                                                       highlightColor: nil,
                                                       note: nil,
                                                       tags: [" Memory "]))
        let annotation2 = try #require(VerseAnnotation(reference: reference2,
                                                       selectedVerses: verseRange2,
                                                       highlightColor: nil,
                                                       note: nil,
                                                       tags: ["memory", "MEMORY"]))

        try repository.save(annotation1)
        try repository.save(annotation2)
        let tags = try modelContainer.mainContext.fetch(FetchDescriptor<StoredTag>())

        #expect(tags.count == 1)
        #expect(tags.first?.normalizedName == "memory")
    }

    /// Delete: delete(id:) removes the annotation while its nullified tag row remains
    @Test func deleteRemovesAnnotationAndLeavesTagRow() throws {
        let modelContainer = try buildModelContainer()
        let repository = SwiftDataLibraryRepository(modelContainer: modelContainer)
        let reference = try buildReference()
        let verseRange = try #require(reference.verseRange)
        let annotation = try #require(VerseAnnotation(reference: reference,
                                                      selectedVerses: verseRange,
                                                      highlightColor: nil,
                                                      note: nil,
                                                      tags: ["memory"]))

        try repository.save(annotation)
        try repository.delete(annotation.id)
        let annotations = try repository.annotations(for: reference)
        let tags = try modelContainer.mainContext.fetch(FetchDescriptor<StoredTag>())

        #expect(annotations == [])
        #expect(tags.count == 1)
        #expect(tags.first?.normalizedName == "memory")
        #expect(tags.first?.annotations?.isEmpty != false)
    }

    private func buildRepository() throws -> SwiftDataLibraryRepository {
        try SwiftDataLibraryRepository(modelContainer: buildModelContainer())
    }

    private func buildReference(chapter: Int = 1) throws -> ScriptureReference {
        try #require(ScriptureReference(translationID: 123,
                                        bookCode: "GEN",
                                        chapter: chapter,
                                        startVerse: 16,
                                        endVerse: nil))
    }

    private func buildModelContainer() throws -> ModelContainer {
        let schema = Schema([
            StoredVerseAnnotation.self,
            StoredTag.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema,
                                                    isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema,
                                  configurations: [modelConfiguration])
    }
}
