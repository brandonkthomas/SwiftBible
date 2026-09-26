//
//  DiskPassageCache.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 2026-09-25.
//

import Foundation

/// On-disk (FileManager) implementation of PassageCache
///
/// Actor rather than final class: an actor protects its own state and only allows one task
/// inside at a time, so callers can use it from anywhere. Its async functions also run off
/// the main actor, which matters because file I/O is slow
///
/// MainActor is the "UI thread" actor -- SwiftUI views and @Observable stores belong to it,
/// and it is the default isolation for unannotated code in this project (Xcode 26 default)
actor DiskPassageCache: PassageCache {

    // MARK: Properties (Private)

    /// Shared instance is safe to use from multiple threads; only a delegate would require our own
    private let fileManager: FileManager = .default

    /// Directory holding the cache files themselves (base directory + our own subfolders)
    private let passageDirectory: URL

    /// Has the directory been created this session? Avoids a filesystem call per save
    private var didCreatePassageDirectory = false

    // MARK: Init

    /// - Parameter baseDirectory: where the cache folder lives; defaults to the system Caches
    ///   directory, which iOS already excludes from iCloud and device backups.
    ///   Tests pass a temporary directory so they never touch the real cache
    init(baseDirectory: URL? = nil) throws {
        // FileManager.default rather than self.fileManager: stored properties are not readable
        // until every property has a value
        let resolvedBase = try baseDirectory
            ?? FileManager.default.url(for: .cachesDirectory,
                                       in: .userDomainMask,
                                       appropriateFor: nil,
                                       create: true)

        self.passageDirectory = resolvedBase
            .appending(path: "net.brandonthomas.SwiftBible", directoryHint: .isDirectory)
            .appending(path: "PassageCache", directoryHint: .isDirectory)
    }

    // MARK: Functions

    /// Persists a Passage as JSON, replacing any existing entry for the same key
    func save(_ passage: Passage, for key: BiblePassageKey) async throws {
        try createPassageDirectoryIfNeeded()

        let fileContents = try JSONEncoder().encode(passage)

        // atomic: writes to a temp file and swaps it in, so a crash mid-write cannot
        // leave a half-written file behind for the next launch to read
        try fileContents.write(to: fileUrl(for: key), options: .atomic)
    }

    /// Returns the cached Passage for a key, or nil when it is absent or unreadable
    ///
    /// Any failure counts as a miss so the caller can fall back to the network. Unreadable
    /// files are deleted rather than left to occupy space forever
    func passage(for key: BiblePassageKey) async throws -> Passage? {
        let url = fileUrl(for: key)

        // Nothing cached for this key yet: a plain miss, not a failure
        guard fileManager.fileExists(atPath: url.path(percentEncoded: false)) else {
            return nil
        }

        do {
            let fileContents = try Data(contentsOf: url)
            return try JSONDecoder().decode(Passage.self, from: fileContents)
        } catch {
            // Corrupt or truncated file: discard it and report a miss
            try? fileManager.removeItem(at: url)
            return nil
        }
    }

    // MARK: Functions (Private Helpers)

    /// File location for one key; does not touch the filesystem
    ///
    /// The name must be stable across launches, so it is built from the key's own fields
    /// rather than hashValue, whose seed changes every time the process starts
    private func fileUrl(for key: BiblePassageKey) -> URL {
        // Defensive: keep the filename to characters that are safe on any filesystem
        let bookCode = key.bookCode.replacingOccurrences(of: "[^a-zA-Z0-9]",
                                                        with: "-",
                                                        options: .regularExpression)

        let fileName = "sbc_\(key.translationID)_\(bookCode)_\(key.chapter).json"

        return passageDirectory.appending(path: fileName, directoryHint: .notDirectory)
    }

    /// Creates the cache directory the first time it is needed
    ///
    /// withIntermediateDirectories: true creates missing parents and succeeds when the
    /// directory already exists, so this is safe to call after an external deletion too
    private func createPassageDirectoryIfNeeded() throws {
        guard !didCreatePassageDirectory else {
            return
        }

        try fileManager.createDirectory(at: passageDirectory,
                                        withIntermediateDirectories: true)

        didCreatePassageDirectory = true
    }
}
