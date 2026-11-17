//
//  SwiftBibleSchemaV1MigrationTests.swift
//  SwiftBibleTests
//
//  Created by Brandon Thomas on 2026-11-16.
//

import Foundation
import SwiftData
import Testing
@testable import SwiftBible

/// A store written by the frozen V1 classes must open the way the app opens it
/// (`ModelContainer.library(configuration:)`) and read back the same annotations.
/// Keeps passing as V2, V3... are added; that is the point.
@MainActor
struct SwiftBibleSchemaV1MigrationTests {

    /// every annotation the fixture wrote comes back through the repository unchanged
    @Test func everyV1AnnotationSurvives() throws {
        let directoryURL = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directoryURL) }
        let storeURL = directoryURL.appending(path: "Library.store")

        let expected = try SwiftBibleSchemaV1Fixture.seedStore(at: storeURL)

        let modelContainer = try ModelContainer.library(configuration: ModelConfiguration(url: storeURL,
                                                                                        cloudKitDatabase: .none))
        let migrated = try SwiftDataLibraryRepository(modelContainer: modelContainer).allAnnotations()

        #expect(normalized(migrated) == normalized(expected))
    }

    /// the fixture covers every stored case, so a lossy change to any field fails the test above
    @Test func fixtureCoversEveryStoredCase() throws {
        let directoryURL = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directoryURL) }

        let expected = try SwiftBibleSchemaV1Fixture.seedStore(at: directoryURL.appending(path: "Library.store"))

        let tagged = expected.filter { $0.content.type == .tags }
        let allTagNames = tagged.flatMap(\.tagNames).map(StoredTag.normalize)

        #expect(Set(expected.compactMap(\.highlightColor)) == Set(VerseAnnotationHighlightColor.allCases))
        #expect(expected.contains { $0.content.type == .note })
        #expect(expected.contains { $0.tagNames.count >= 2 })
        #expect(allTagNames.count > Set(allTagNames).count) // one tag is shared by two annotations
        #expect(expected.contains { $0.endVerse != nil })
        #expect(expected.contains { $0.updatedAt != nil })
    }

    /// a tag shared by two annotations is still one row linked to both
    @Test func sharedTagStaysOneRow() throws {
        let directoryURL = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directoryURL) }
        let storeURL = directoryURL.appending(path: "Library.store")

        let expected = try SwiftBibleSchemaV1Fixture.seedStore(at: storeURL)

        let modelContainer = try ModelContainer.library(configuration: ModelConfiguration(url: storeURL,
                                                                                        cloudKitDatabase: .none))
        let storedTags = try modelContainer.mainContext.fetch(FetchDescriptor<StoredTag>())
        let distinctTagNames = Set(expected.flatMap(\.tagNames).map(StoredTag.normalize))

        #expect(storedTags.count == distinctTagNames.count)
        #expect(storedTags.contains { ($0.annotations?.count ?? 0) >= 2 })
    }

    // MARK: Functions (Private)

    private func makeTemporaryDirectory() throws -> URL {
        let directoryURL = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        return directoryURL
    }

    /// to-many relationships have no stored order, so tag names are compared sorted;
    /// annotations are sorted by id so fetch order doesn't matter
    private func normalized(_ annotations: [VerseAnnotation]) -> [VerseAnnotation] {
        annotations
            .map { annotation in
                var annotation = annotation
                if case .tags(let names) = annotation.content {
                    annotation.content = .tags(names.sorted())
                }
                return annotation
            }
            .sorted { $0.id.uuidString < $1.id.uuidString }
    }
}
