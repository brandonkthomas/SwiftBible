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

    /// - Parameter baseDirectory: where the cache folder lives; defaults to AppDirectories.caches
    ///
    /// Tests pass a temporary directory so they never touch the real cache
    init(baseDirectory: URL? = nil) throws {
        let resolvedBase = baseDirectory ?? AppDirectories.caches

        self.passageDirectory = resolvedBase
            .appending(path: "Passage", directoryHint: .isDirectory)
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

    /// Deletes the cached Passage for a key; a key with no file is not an error
    func removePassage(for key: BiblePassageKey) async throws {
        let url = fileUrl(for: key)

        guard fileManager.fileExists(atPath: url.path(percentEncoded: false)) else {
            return
        }

        try fileManager.removeItem(at: url)
    }

    /// Reads one translation's verse-limited chapter list, then deletes that translation's
    /// passage files the list does not include
    ///
    /// Files can be left out when the app quits between saving a passage and saving the list,
    /// or when passages were cached under another policy. A missing or unreadable list counts
    /// as empty, so every passage file of the translation is deleted
    func verseLimitEntries(for translationID: Translation.ID) async throws -> [PassageCacheEntry] {
        let indexUrl = indexFileUrl(for: translationID)
        var entries: [PassageCacheEntry] = []

        if fileManager.fileExists(atPath: indexUrl.path(percentEncoded: false)) {
            do {
                let fileContents = try Data(contentsOf: indexUrl)
                entries = try JSONDecoder().decode([PassageCacheEntry].self, from: fileContents)
            } catch {
                try? fileManager.removeItem(at: indexUrl)
            }
        }

        // An entry whose file is gone (deleted as corrupt, or purged by iOS) no longer counts
        entries.removeAll { entry in
            !fileManager.fileExists(atPath: fileUrl(for: entry.key).path(percentEncoded: false))
        }

        try removePassageFiles(of: translationID,
                               keeping: Set(entries.map { fileUrl(for: $0.key).lastPathComponent }))

        return entries
    }

    /// Replaces one translation's verse-limited chapter list
    func saveVerseLimitEntries(_ entries: [PassageCacheEntry],
                               for translationID: Translation.ID) async throws {
        try createPassageDirectoryIfNeeded()

        let fileContents = try JSONEncoder().encode(entries)
        try fileContents.write(to: indexFileUrl(for: translationID), options: .atomic)
    }

    // MARK: Functions (Private Helpers)

    /// Deletes every passage file of one translation whose name is not in keptFileNames
    private func removePassageFiles(of translationID: Translation.ID,
                                    keeping keptFileNames: Set<String>) throws {
        // Nothing has been cached yet
        guard fileManager.fileExists(atPath: passageDirectory.path(percentEncoded: false)) else {
            return
        }

        // Trailing underscore: translation 5's prefix must not match translation 59's files
        let translationPrefix = "sbc_\(translationID)_"

        let fileUrls = try fileManager.contentsOfDirectory(at: passageDirectory,
                                                           includingPropertiesForKeys: nil)

        for fileUrl in fileUrls {
            let fileName = fileUrl.lastPathComponent

            if fileName.hasPrefix(translationPrefix), !keptFileNames.contains(fileName) {
                try fileManager.removeItem(at: fileUrl)
            }
        }
    }

    /// Location of one translation's verse-limited chapter list; "sbi_" so it never matches
    /// the "sbc_" passage file prefix
    private func indexFileUrl(for translationID: Translation.ID) -> URL {
        passageDirectory.appending(path: "sbi_\(translationID).json", directoryHint: .notDirectory)
    }

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
