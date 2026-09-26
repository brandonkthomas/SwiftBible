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
            .appending(path: "PassageCache", directoryHint: .isDirectory)
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
}
