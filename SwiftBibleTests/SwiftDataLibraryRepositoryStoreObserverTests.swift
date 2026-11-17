//
//  SwiftDataLibraryRepositoryStoreObserverTests.swift
//  SwiftBibleTests
//
//  Created by Brandon Thomas on 2026-11-16.
//

import Foundation
import SwiftData
import Testing
@testable import SwiftBible

/// The repository listens for the store's write notification and runs `handleStoreChange()`.
/// The notification is posted for every store in the process, so the repository must ignore
/// stores other than its own.
///
/// Uses on-disk stores in a temporary folder: every in-memory store reports the same URL
/// (`/dev/null`), so in-memory stores can't tell each other apart.
@MainActor
struct SwiftDataLibraryRepositoryStoreObserverTests {

    /// a save from another context (as iCloud's importer does) bumps changeCount without
    /// anyone calling the repository
    @Test func saveFromAnotherContextBumpsChangeCount() async throws {
        let directoryURL = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directoryURL) }
        let repository = try buildRepository(storeURL: directoryURL.appending(path: "own.store"))
        let before = repository.changeCount

        let importer = ModelContext(repository.container)
        importer.insert(StoredVerseAnnotation(id: UUID(),
                                              translationID: 111,
                                              bookCode: "JHN",
                                              chapter: 3,
                                              startVerse: 16,
                                              highlightColor: .yellow,
                                              createdAt: .now))
        try importer.save()

        let didBump = await waitUntil { repository.changeCount > before }
        #expect(didBump)
        #expect(try repository.allAnnotations().count == 1)
    }

    /// a save to a different store file leaves this repository's changeCount alone
    @Test func savesToAnotherStoreAreIgnored() async throws {
        let directoryURL = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directoryURL) }
        let repository = try buildRepository(storeURL: directoryURL.appending(path: "own.store"))
        let otherContainer = try ModelContainer.library(configuration: ModelConfiguration(url: directoryURL.appending(path: "other.store"),
                                                                                          cloudKitDatabase: .none))
        let before = repository.changeCount

        let otherContext = ModelContext(otherContainer)
        otherContext.insert(StoredTag(id: UUID(), displayName: "Hope", normalizedName: "hope"))
        try otherContext.save()

        let didBump = await waitUntil { repository.changeCount > before }
        #expect(!didBump)
    }

    // MARK: Functions (Private)

    private func buildRepository(storeURL: URL) throws -> SwiftDataLibraryRepository {
        let modelConfiguration = ModelConfiguration(url: storeURL, cloudKitDatabase: .none)
        return try SwiftDataLibraryRepository(modelContainer: .library(configuration: modelConfiguration))
    }

    private func makeDirectory() throws -> URL {
        let directoryURL = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        return directoryURL
    }

    /// The notification arrives on the main queue after the save returns; sleeping lets it through.
    /// Returns false if `condition` is still false after `timeout`.
    private func waitUntil(timeout: Duration = .seconds(1), _ condition: () -> Bool) async -> Bool {
        let deadline = ContinuousClock.now + timeout
        while ContinuousClock.now < deadline {
            if condition() { return true }
            try? await Task.sleep(for: .milliseconds(20))
        }
        return condition()
    }
}
