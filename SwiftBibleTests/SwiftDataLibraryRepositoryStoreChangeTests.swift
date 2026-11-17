//
//  SwiftDataLibraryRepositoryStoreChangeTests.swift
//  SwiftBibleTests
//
//  Created by Brandon Thomas on 2026-11-16.
//

import Foundation
import SwiftData
import Testing
@testable import SwiftBible

/// iCloud writes rows through its own context, so `changeCount` (bumped only by this
/// repository's save/delete) never moves on its own. `handleStoreChange()` is what runs when
/// the store reports a write: merge any synced duplicate tags, then notify observers once.
@MainActor
struct SwiftDataLibraryRepositoryStoreChangeTests {

    private static let lowID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    private static let highID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!

    /// with nothing to merge, observers still hear about the change, exactly once
    @Test func storeChangeBumpsChangeCountOnce() throws {
        let repository = try buildRepository()
        repository.context.insert(StoredTag(id: Self.lowID, displayName: "Hope", normalizedName: "hope"))
        try repository.context.save()
        let before = repository.changeCount

        try repository.handleStoreChange()

        #expect(repository.changeCount == before + 1)
    }

    /// synced duplicates are merged, and the merge's own bump is the only one
    @Test func storeChangeMergesDuplicatesAndBumpsOnce() throws {
        let repository = try buildRepository()
        repository.context.insert(StoredTag(id: Self.lowID, displayName: "Grace", normalizedName: "grace"))
        repository.context.insert(StoredTag(id: Self.highID, displayName: "grace", normalizedName: "grace"))
        try repository.context.save()
        let before = repository.changeCount

        try repository.handleStoreChange()

        let storedTags = try repository.context.fetch(FetchDescriptor<StoredTag>())
        #expect(storedTags.map(\.id) == [Self.lowID])
        #expect(repository.changeCount == before + 1)
    }

    /// rows another context saved (as iCloud's importer does) are returned with no extra
    /// refresh step, including edits to rows this repository already fetched
    @Test func rowsSavedByAnotherContextAreReturned() throws {
        let repository = try buildRepository()
        let id = UUID()
        repository.context.insert(StoredVerseAnnotation(id: id,
                                                        translationID: 111,
                                                        bookCode: "JHN",
                                                        chapter: 3,
                                                        startVerse: 16,
                                                        highlightColor: .yellow,
                                                        createdAt: .now))
        try repository.context.save()
        _ = try repository.allAnnotations()

        let importer = ModelContext(repository.container)
        let imported = try #require(try importer.fetch(FetchDescriptor<StoredVerseAnnotation>()).first)
        imported.highlightColor = .blue
        importer.insert(StoredVerseAnnotation(id: UUID(),
                                              translationID: 111,
                                              bookCode: "JHN",
                                              chapter: 3,
                                              startVerse: 17,
                                              highlightColor: .green,
                                              createdAt: .now))
        try importer.save()
        try repository.handleStoreChange()

        let annotations = try repository.allAnnotations()
        #expect(annotations.count == 2)
        #expect(annotations.first { $0.id == id }?.content == .highlight(.blue))
    }

    // MARK: Functions (Private)

    private func buildRepository() throws -> SwiftDataLibraryRepository {
        let modelConfiguration = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try SwiftDataLibraryRepository(modelContainer: .library(configuration: modelConfiguration))
    }
}
