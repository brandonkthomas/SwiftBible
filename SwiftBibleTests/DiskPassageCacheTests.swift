//
//  DiskPassageCacheTests.swift
//  SwiftBibleTests
//
//  Created by Brandon Thomas on 2026-09-25.
//

import Testing
import Foundation
@testable import SwiftBible

@MainActor // required so DiskPassageCache's init doesn't fail
struct DiskPassageCacheTests {

    /// Fresh, empty directory for one test; caller deletes it when done
    private func makeTempDirectory() -> URL {
        FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    }

    /// Cache misses return nil and do not throw (only disk read errors can/should throw)
    @Test func missReturnsNilAndDoesNotThrow() async throws {
        let tempDirectory = makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let cache = try DiskPassageCache(baseDirectory: tempDirectory)

        let key = BiblePassageKey(translationID: 1234,
                                  bookCode: "GEN",
                                  chapter: 1)

        #expect(try await cache.passage(for: key) == nil)
    }

    /// Saving then reading the same key returns the saved passage
    @Test func saveThenReadReturnsPassage() async throws {
        let tempDirectory = makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let cache = try DiskPassageCache(baseDirectory: tempDirectory)

        let key = BiblePassageKey(translationID: 1234,
                                  bookCode: "GEN",
                                  chapter: 1)
        let passage = Passage(id: "GEN.1",
                              reference: "Test",
                              htmlContent: "<div></div>")

        try await cache.save(passage, for: key)
        #expect(try await cache.passage(for: key) == passage)
    }

    /// A cache file that isn't valid JSON is treated as a miss rather than a thrown error
    @Test func corruptFileReadAsMiss() async throws {
        let tempDirectory = makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let cache = try DiskPassageCache(baseDirectory: tempDirectory)

        let key = BiblePassageKey(translationID: 1234,
                                  bookCode: "GEN",
                                  chapter: 1)

        // Save a valid entry first so the cache directory exists, then clobber the file
        // it wrote with garbage bytes at the same, deterministic path
        try await cache.save(Passage(id: "GEN.1", reference: "Test", htmlContent: "<div></div>"),
                             for: key)

        let fileUrl = tempDirectory
            .appending(path: "net.brandonthomas.SwiftBible", directoryHint: .isDirectory)
            .appending(path: "Cache", directoryHint: .isDirectory)
            .appending(path: "Passage", directoryHint: .isDirectory)
            .appending(path: "sbc_1234_GEN_1.json", directoryHint: .notDirectory)

        try Data("not valid json".utf8).write(to: fileUrl, options: .atomic)

        #expect(try await cache.passage(for: key) == nil)
    }

    /// A second DiskPassageCache pointed at the same directory sees what the first one wrote,
    /// confirming persistence doesn't depend on any in-memory state of the writer
    @Test func secondCacheOnSameDirectoryReadsFirstCachesWrite() async throws {
        let tempDirectory = makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let firstCache = try DiskPassageCache(baseDirectory: tempDirectory)
        let secondCache = try DiskPassageCache(baseDirectory: tempDirectory)

        let key = BiblePassageKey(translationID: 1234,
                                  bookCode: "GEN",
                                  chapter: 1)
        let passage = Passage(id: "GEN.1",
                              reference: "Test",
                              htmlContent: "<div></div>")

        try await firstCache.save(passage, for: key)
        #expect(try await secondCache.passage(for: key) == passage)
    }

    // MARK: Removal and verse-limit list

    /// A removed passage reads as a miss
    @Test func removeDeletesSavedPassage() async throws {
        let tempDirectory = makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let cache = try DiskPassageCache(baseDirectory: tempDirectory)
        let key = BiblePassageKey(translationID: 59, bookCode: "GEN", chapter: 1)

        try await cache.save(Passage(id: "GEN.1", reference: "Test", htmlContent: "<div></div>"),
                             for: key)
        try await cache.removePassage(for: key)

        #expect(try await cache.passage(for: key) == nil)
    }

    /// Removing a key that was never cached is not an error
    @Test func removeMissingPassageDoesNotThrow() async throws {
        let tempDirectory = makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let cache = try DiskPassageCache(baseDirectory: tempDirectory)

        try await cache.removePassage(for: BiblePassageKey(translationID: 59, bookCode: "GEN", chapter: 1))
    }

    /// The saved list survives a new DiskPassageCache (next launch) in its saved order
    @Test func verseLimitEntriesPersistAcrossInstances() async throws {
        let tempDirectory = makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let firstCache = try DiskPassageCache(baseDirectory: tempDirectory)
        let entries = [2, 1].map { chapter in
            PassageCacheEntry(key: BiblePassageKey(translationID: 59, bookCode: "GEN", chapter: chapter),
                              verseCount: 25)
        }

        for entry in entries {
            try await firstCache.save(Passage(id: "GEN.\(entry.key.chapter)", reference: "Test", htmlContent: "<div></div>"),
                                      for: entry.key)
        }
        try await firstCache.saveVerseLimitEntries(entries, for: 59)

        let secondCache = try DiskPassageCache(baseDirectory: tempDirectory)
        #expect(try await secondCache.verseLimitEntries(for: 59) == entries)
    }

    /// Reading the list deletes that translation's unlisted passage files and drops listed
    /// entries whose file is gone; other translations (including ID prefixes like 5 vs 59)
    /// are untouched
    @Test func verseLimitEntriesRemovesUnlistedPassages() async throws {
        let tempDirectory = makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let cache = try DiskPassageCache(baseDirectory: tempDirectory)
        let passage = Passage(id: "GEN.1", reference: "Test", htmlContent: "<div></div>")

        let listedKey = BiblePassageKey(translationID: 59, bookCode: "GEN", chapter: 1)
        let unlistedKey = BiblePassageKey(translationID: 59, bookCode: "GEN", chapter: 2)
        let missingKey = BiblePassageKey(translationID: 59, bookCode: "GEN", chapter: 3)
        let otherTranslationKey = BiblePassageKey(translationID: 5, bookCode: "GEN", chapter: 2)

        try await cache.save(passage, for: listedKey)
        try await cache.save(passage, for: unlistedKey)
        try await cache.save(passage, for: otherTranslationKey)
        try await cache.saveVerseLimitEntries([PassageCacheEntry(key: missingKey, verseCount: 10),
                                               PassageCacheEntry(key: listedKey, verseCount: 31)],
                                              for: 59)

        #expect(try await cache.verseLimitEntries(for: 59)
                == [PassageCacheEntry(key: listedKey, verseCount: 31)])
        #expect(try await cache.passage(for: listedKey) == passage)
        #expect(try await cache.passage(for: unlistedKey) == nil)
        #expect(try await cache.passage(for: otherTranslationKey) == passage)
    }

    /// With no saved list, every passage file of that translation is deleted
    @Test func verseLimitEntriesWithoutListRemovesTranslationPassages() async throws {
        let tempDirectory = makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let cache = try DiskPassageCache(baseDirectory: tempDirectory)
        let key = BiblePassageKey(translationID: 59, bookCode: "GEN", chapter: 1)

        try await cache.save(Passage(id: "GEN.1", reference: "Test", htmlContent: "<div></div>"),
                             for: key)

        #expect(try await cache.verseLimitEntries(for: 59).isEmpty)
        #expect(try await cache.passage(for: key) == nil)
    }
}
