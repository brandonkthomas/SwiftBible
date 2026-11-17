//
//  SwiftDataLibraryRepositoryTagMergeTests.swift
//  SwiftBibleTests
//
//  Created by Brandon Thomas on 2026-11-16.
//

import Foundation
import SwiftData
import Testing
@testable import SwiftBible

/// Two devices offline can each create a tag with the same normalized name; iCloud then syncs
/// both rows. Every device must pick the same survivor (lowest `id.uuidString`), or two devices
/// merging at once would each delete the other's choice.
@MainActor
struct SwiftDataLibraryRepositoryTagMergeTests {

    private static let lowID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    private static let highID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!

    /// duplicates collapse into the lowest-id tag, which keeps its display name and gains every link;
    /// an annotation that was linked to both ends up with the tag once
    @Test func mergeKeepsLowestIDTag() throws {
        let repository = try buildRepository()
        let (low, high) = insertDuplicateTags(into: repository.context)
        let onHigh = insertAnnotation(tags: [high], into: repository.context)
        let onLow = insertAnnotation(tags: [low], into: repository.context)
        let onBoth = insertAnnotation(tags: [low, high], into: repository.context)
        try repository.context.save()

        try repository.mergeDuplicateTags()

        let storedTags = try repository.context.fetch(FetchDescriptor<StoredTag>())
        let survivor = try #require(storedTags.first)
        #expect(storedTags.count == 1)
        #expect(survivor.id == Self.lowID)
        #expect(survivor.displayName == "Grace")
        #expect(Set(survivor.annotations?.map(\.id) ?? []) == [onHigh.id, onLow.id, onBoth.id])

        let annotations = try repository.allAnnotations()
        #expect(annotations.count == 3)
        #expect(annotations.allSatisfy { $0.tagNames == ["Grace"] })
    }

    /// saving before a merge has run still links one tag, the same one a merge would keep
    @Test func saveLinksOneTagWhenDuplicatesExist() throws {
        let repository = try buildRepository()
        _ = insertDuplicateTags(into: repository.context)
        try repository.context.save()

        let reference = try #require(ScriptureReference(translationID: 111,
                                                        bookCode: "MAT",
                                                        chapter: 5,
                                                        startVerse: 9,
                                                        endVerse: nil))
        let annotation = try #require(VerseAnnotation(reference: reference,
                                                      selectedVerses: 9...9,
                                                      content: .tags(["GRACE"])))
        try repository.save(annotation)

        let stored = try repository.context.fetch(FetchDescriptor<StoredVerseAnnotation>())
        let savedTags = try #require(stored.first { $0.id == annotation.id }?.tags)
        #expect(savedTags.map(\.id) == [Self.lowID])
    }

    /// a merge that changes something notifies observers once; one with nothing to merge does not
    @Test func mergeBumpsChangeCountOnlyWhenItMerges() throws {
        let repository = try buildRepository()
        let single = StoredTag(id: Self.lowID, displayName: "Hope", normalizedName: "hope")
        repository.context.insert(single)
        try repository.context.save()

        let before = repository.changeCount
        try repository.mergeDuplicateTags()
        #expect(repository.changeCount == before)

        repository.context.insert(StoredTag(id: Self.highID, displayName: "hope", normalizedName: "hope"))
        try repository.context.save()
        try repository.mergeDuplicateTags()
        #expect(repository.changeCount == before + 1)
    }

    // MARK: Functions (Private)

    private func buildRepository() throws -> SwiftDataLibraryRepository {
        let modelConfiguration = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try SwiftDataLibraryRepository(modelContainer: .library(configuration: modelConfiguration))
    }

    /// "Grace" (lowest id) and "grace" share the normalized name "grace"
    private func insertDuplicateTags(into context: ModelContext) -> (low: StoredTag, high: StoredTag) {
        let low = StoredTag(id: Self.lowID, displayName: "Grace", normalizedName: "grace")
        let high = StoredTag(id: Self.highID, displayName: "grace", normalizedName: "grace")
        context.insert(low)
        context.insert(high)
        return (low, high)
    }

    private func insertAnnotation(tags: [StoredTag], into context: ModelContext) -> StoredVerseAnnotation {
        let annotation = StoredVerseAnnotation(id: UUID(),
                                               translationID: 111,
                                               bookCode: "JHN",
                                               chapter: 3,
                                               startVerse: 16,
                                               createdAt: .now)
        context.insert(annotation)
        annotation.tags = tags
        return annotation
    }
}
