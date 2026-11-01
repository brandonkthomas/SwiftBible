//
//  DiskCatalogCacheTests.swift
//  SwiftBibleTests
//
//  Created by Brandon Thomas on 2026-10-22.
//

import Testing
import Foundation
@testable import SwiftBible

@MainActor // required so DiskCatalogCache's init doesn't fail
struct DiskCatalogCacheTests {

    /// Fresh, empty directory for one test; caller deletes it when done
    private func makeTempDirectory() -> URL {
        FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    }

    // MARK: Translations

    /// Cache misses return nil and do not throw (only disk read errors can/should throw)
    @Test func missedTranslationReturnsNilAndDoesNotThrow() async throws {
        let tempDirectory = makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let cache = try DiskCatalogCache(baseDirectory: tempDirectory)

        #expect(try await cache.translations(for: "en") == nil)
    }

    /// Saving then reading the same key returns the saved translation
    @Test func saveTranslationThenReadReturnsTranslation() async throws {
        let tempDirectory = makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let cache = try DiskCatalogCache(baseDirectory: tempDirectory)

        let entry = testTranslationsEntry()

        try await cache.save(entry, for: "en")
        let saved = try #require(try await cache.translations(for: "en"))

        #expect(saved.value == entry.value)
        #expect(saved.createdOn == entry.createdOn)
        #expect(saved.createdByBuildNumber == entry.createdByBuildNumber)
    }

    /// A cache file that isn't valid JSON is treated as a miss rather than a thrown error
    @Test func corruptTranslationFileReadAsMiss() async throws {
        let tempDirectory = makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let cache = try DiskCatalogCache(baseDirectory: tempDirectory)

        // Save a valid entry first so the cache directory exists, then clobber the file
        // it wrote with garbage bytes at the same, deterministic path
        try await cache.save(testTranslationsEntry(), for: "en")

        let fileUrl = catalogFileUrl(in: tempDirectory, fileName: "sbc_trns_en.json")

        try Data("not valid json".utf8).write(to: fileUrl, options: .atomic)

        #expect(try await cache.translations(for: "en") == nil)
    }

    /// A file in the pre-CatalogCacheEntry format (plain JSON array of translations) is
    /// treated as a miss and deleted
    @Test func oldFormatTranslationFileReadAsMissAndDeleted() async throws {
        let tempDirectory = makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let cache = try DiskCatalogCache(baseDirectory: tempDirectory)

        let fileUrl = catalogFileUrl(in: tempDirectory, fileName: "sbc_trns_en.json")

        try FileManager.default.createDirectory(at: fileUrl.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        try JSONEncoder().encode(testTranslations()).write(to: fileUrl, options: .atomic)

        #expect(try await cache.translations(for: "en") == nil)
        #expect(!FileManager.default.fileExists(atPath: fileUrl.path(percentEncoded: false)))
    }

    /// A second DiskCatalogCache pointed at the same directory sees what the first one wrote,
    /// confirming persistence doesn't depend on any in-memory state of the writer
    @Test func secondCacheOnSameDirectoryReadsFirstCachesWrite() async throws {
        let tempDirectory = makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let firstCache = try DiskCatalogCache(baseDirectory: tempDirectory)
        let secondCache = try DiskCatalogCache(baseDirectory: tempDirectory)

        let entry = testTranslationsEntry()

        try await firstCache.save(entry, for: "en")
        let saved = try #require(try await secondCache.translations(for: "en"))

        #expect(saved.value == entry.value)
        #expect(saved.createdOn == entry.createdOn)
        #expect(saved.createdByBuildNumber == entry.createdByBuildNumber)
    }

    // MARK: Books

    /// Cache misses return nil and do not throw (only disk read errors can/should throw)
    @Test func missedBookReturnsNilAndDoesNotThrow() async throws {
        let tempDirectory = makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let cache = try DiskCatalogCache(baseDirectory: tempDirectory)

        #expect(try await cache.books(for: 1849) == nil)
    }

    /// Saving then reading the same key returns the saved books
    @Test func saveBookThenReadReturnsBook() async throws {
        let tempDirectory = makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let cache = try DiskCatalogCache(baseDirectory: tempDirectory)

        let entry = testBooksEntry()

        try await cache.save(entry, for: 1849)
        let saved = try #require(try await cache.books(for: 1849))

        #expect(saved.value == entry.value)
        #expect(saved.createdOn == entry.createdOn)
        #expect(saved.createdByBuildNumber == entry.createdByBuildNumber)
    }

    /// A cache file that isn't valid JSON is treated as a miss rather than a thrown error
    @Test func corruptBookFileReadAsMiss() async throws {
        let tempDirectory = makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let cache = try DiskCatalogCache(baseDirectory: tempDirectory)

        // Save a valid entry first so the cache directory exists, then clobber the file
        // it wrote with garbage bytes at the same, deterministic path
        try await cache.save(testBooksEntry(), for: 1849)

        let fileUrl = catalogFileUrl(in: tempDirectory, fileName: "sbc_bks_1849.json")

        try Data("not valid json".utf8).write(to: fileUrl, options: .atomic)

        #expect(try await cache.books(for: 1849) == nil)
    }

    /// A second DiskCatalogCache pointed at the same directory sees what the first one wrote,
    /// confirming persistence doesn't depend on any in-memory state of the writer
    @Test func secondCacheOnSameDirectoryReadsFirstCachesBookWrite() async throws {
        let tempDirectory = makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let firstCache = try DiskCatalogCache(baseDirectory: tempDirectory)
        let secondCache = try DiskCatalogCache(baseDirectory: tempDirectory)

        let entry = testBooksEntry()

        try await firstCache.save(entry, for: 1849)
        let saved = try #require(try await secondCache.books(for: 1849))

        #expect(saved.value == entry.value)
        #expect(saved.createdOn == entry.createdOn)
        #expect(saved.createdByBuildNumber == entry.createdByBuildNumber)
    }

    // MARK: Private Helpers

    /// Fixed date so round-trip comparisons don't depend on the wall clock
    private let createdOn = Date(timeIntervalSinceReferenceDate: 815_000_000)
    private let buildNumber = "42"

    /// Same path DiskCatalogCache builds internally for a given cache file name
    private func catalogFileUrl(in baseDirectory: URL, fileName: String) -> URL {
        baseDirectory
            .appending(path: "net.brandonthomas.SwiftBible", directoryHint: .isDirectory)
            .appending(path: "Cache", directoryHint: .isDirectory)
            .appending(path: "Catalog", directoryHint: .isDirectory)
            .appending(path: fileName, directoryHint: .notDirectory)
    }

    private func testTranslationsEntry() -> CatalogCacheEntry<[Translation]> {
        CatalogCacheEntry(value: testTranslations(),
                          createdOn: createdOn,
                          createdByBuildNumber: buildNumber)
    }

    private func testBooksEntry() -> CatalogCacheEntry<[Book]> {
        CatalogCacheEntry(value: testBooks(),
                          createdOn: createdOn,
                          createdByBuildNumber: buildNumber)
    }

    private func testTranslations() -> [Translation] {
        return [
            Translation(id: 1849,
                        abbreviation: "TPT",
                        title: "The Passion Translation",
                        languageTag: "en",
                        license: "Copyright (c) 2026 by BroadStreet Publishing.",
                        promotionalText: nil,
                        availableBookCodes: ["GEN", "EXO", "LEV"])
        ]
    }

    private func testBooks() -> [Book] {
        return [
            Book(id: "GEN",
                 code: "GEN",
                 displayName: "Genesis",
                 canon: .oldTestament,
                 chapters: [
                    Chapter(id: "GEN.1",
                            number: 1,
                            bookID: "GEN",
                            displayName: "1",
                            verses: [
                                Verse(id: "GEN.1.1",
                                      number: 1,
                                      chapterID: "GEN.1",
                                      bookID: "GEN",
                                      displayName: "1")
                            ])
                 ])
        ]
    }
}
