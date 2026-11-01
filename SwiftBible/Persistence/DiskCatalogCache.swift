//
//  DiskCatalogCache.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 2026-10-22.
//

import Foundation

/// On-disk (FileManager) implementation of CatalogCache
///
/// Actor rather than final class: an actor protects its own state and only allows one task
/// inside at a time, so callers can use it from anywhere. Its async functions also run off
/// the main actor, which matters because file I/O is slow
///
/// MainActor is the "UI thread" actor -- SwiftUI views and @Observable stores belong to it,
/// and it is the default isolation for unannotated code in this project (Xcode 26 default)
actor DiskCatalogCache: CatalogCache {

    // MARK: Properties (Private)

    /// Shared instance is safe to use from multiple threads; only a delegate would require our own
    private let fileManager: FileManager = .default

    /// Directory holding the cache files themselves (base directory + our own subfolders)
    private let catalogDirectory: URL

    /// Has the directory been created this session? Avoids a filesystem call per save
    private var didCreateCatalogDirectory = false

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

        self.catalogDirectory = resolvedBase
            .appending(path: "net.brandonthomas.SwiftBible", directoryHint: .isDirectory)
            .appending(path: "Cache", directoryHint: .isDirectory)
            .appending(path: "Catalog", directoryHint: .isDirectory)
    }

    // MARK: Functions

    /// Returns the cached Translation list for a key (language tag), or nil when it is absent or unreadable
    ///
    /// Any failure counts as a miss so the caller can fall back to the network. Unreadable
    /// files are deleted rather than left to occupy space forever
    func translations(for languageTag: String) async throws -> CatalogCacheEntry<[Translation]>? {
        let url = translationFileUrl(for: languageTag)

        // Nothing cached for this key yet: a plain miss, not a failure
        guard fileManager.fileExists(atPath: url.path(percentEncoded: false)) else {
            return nil
        }

        do {
            let fileContents = try Data(contentsOf: url)
            return try JSONDecoder().decode(CatalogCacheEntry<[Translation]>.self, from: fileContents)
        } catch {
            // Corrupt or truncated file: discard it and report a miss
            try? fileManager.removeItem(at: url)
            return nil
        }
    }

    /// Persists a Translation list as JSON, replacing any existing entry for the same key
    func save(_ translationsEntry: CatalogCacheEntry<[Translation]>,
              for languageTag: String) async throws {
        try createCatalogDirectoryIfNeeded()

        let fileContents = try JSONEncoder().encode(translationsEntry)

        // atomic: writes to a temp file and swaps it in, so a crash mid-write cannot
        // leave a half-written file behind for the next launch to read
        try fileContents.write(to: translationFileUrl(for: languageTag), options: .atomic)
    }

    /// Returns the cached Book list for a key (translation ID), or nil when it is absent or unreadable
    ///
    /// Any failure counts as a miss so the caller can fall back to the network. Unreadable
    /// files are deleted rather than left to occupy space forever
    func books(for translationID: Translation.ID) async throws -> CatalogCacheEntry<[Book]>? {
        let url = bookFileUrl(for: translationID)

        // Nothing cached for this key yet: a plain miss, not a failure
        guard fileManager.fileExists(atPath: url.path(percentEncoded: false)) else {
            return nil
        }

        do {
            let fileContents = try Data(contentsOf: url)
            return try JSONDecoder().decode(CatalogCacheEntry<[Book]>.self, from: fileContents)
        } catch {
            // Corrupt or truncated file: discard it and report a miss
            try? fileManager.removeItem(at: url)
            return nil
        }
    }

    /// Persists a Book list as JSON, replacing any existing entry for the same key
    func save(_ booksEntry: CatalogCacheEntry<[Book]>,
              for translationID: Translation.ID) async throws {
        try createCatalogDirectoryIfNeeded()

        let fileContents = try JSONEncoder().encode(booksEntry)

        // atomic: writes to a temp file and swaps it in, so a crash mid-write cannot
        // leave a half-written file behind for the next launch to read
        try fileContents.write(to: bookFileUrl(for: translationID), options: .atomic)
    }

    // MARK: Functions (Private Helpers)

    /// File location for one key; does not touch the filesystem
    ///
    /// The name must be stable across launches, so it is built from the key's own fields
    /// rather than hashValue, whose seed changes every time the process starts
    private func translationFileUrl(for languageTag: String) -> URL {
        // Defensive: keep the filename to characters that are safe on any filesystem
        let sanitizedLanguageTag = languageTag.replacingOccurrences(of: "[^a-zA-Z0-9]",
                                                                    with: "-",
                                                                    options: .regularExpression)

        return catalogDirectory.appending(path: "sbc_trns_\(sanitizedLanguageTag).json",
                                          directoryHint: .notDirectory)
    }

    /// File location for one key; does not touch the filesystem
    ///
    /// The name must be stable across launches, so it is built from the key's own fields
    /// rather than hashValue, whose seed changes every time the process starts
    private func bookFileUrl(for translationID: Translation.ID) -> URL {
        return catalogDirectory.appending(path: "sbc_bks_\(translationID).json",
                                          directoryHint: .notDirectory)
    }

    /// Creates the cache directory the first time it is needed
    ///
    /// withIntermediateDirectories: true creates missing parents and succeeds when the
    /// directory already exists, so this is safe to call after an external deletion too
    private func createCatalogDirectoryIfNeeded() throws {
        guard !didCreateCatalogDirectory else {
            return
        }

        try fileManager.createDirectory(at: catalogDirectory,
                                        withIntermediateDirectories: true)

        didCreateCatalogDirectory = true
    }
}
