//
//  BiblePassageStore.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 2026-09-13.
//

import Foundation
import OSLog

/// Ownership model/cache for loaded Passages
///
/// On request, if cached, return; else load > cache > return
///
/// Cache itself is not directly accessible; use public entry point functions
final class BiblePassageStore {

    // MARK: Properties (Private)

    /// Used for loading passages if they do not exist in the cache
    private let repository: any BibleRepository

    private static let logger = Logger(subsystem: "SwiftBible", category: "BiblePassageStore")

    // MARK: Properties (Private, Cache)

    /// Stores any cached values; NOT externally readable (must use public overloads)
    private var loadedBiblePassageCache: [BiblePassageKey: LoadedBiblePassage] = [:]

    /// Stores HTML requests from network clientside (lives alongside above cache; they work in tandem)
    private let passageCache: any PassageCache

    /// Tracks all currently-in-flight requests (if any) to prevent duplicate work
    private var inFlightRequests: [BiblePassageKey: Task<LoadedBiblePassage, Error>] = [:]

    /// Keys of in-memory passages under a .memoryOnly policy, least recently used first
    private var memoryOnlyKeysByLastUse: [BiblePassageKey] = []

    /// Cached chapters per translation under a .diskLimited policy, least recently used first
    ///
    /// Read from the passage cache the first time each translation is requested this launch
    private var diskLimitedEntries: [Translation.ID: [PassageCacheEntry]] = [:]

    /// In-flight reads of diskLimitedEntries, so concurrent requests read each translation once
    private var diskLimitedEntryLoads: [Translation.ID: Task<[PassageCacheEntry], Never>] = [:]

    // MARK: Init

    init(repository: any BibleRepository,
         passageCache: any PassageCache) {
        self.repository = repository
        self.passageCache = passageCache
    }

    // MARK: Functions

    /// Retrieve a passage by ID.
    /// If it exists in cache, return; else, load + persist to cache + return
    func passage(for key: BiblePassageKey) async throws -> LoadedBiblePassage {
        // the provider's terms decide where (and how much of) its passages may be kept
        let cachePolicy = repository.passageCachePolicy(for: key.translationID)

        // The saved chapter list must be read before any disk access: reading it deletes
        // passage files it does not include, which would otherwise catch a just-saved file
        if case .diskLimited = cachePolicy {
            await loadDiskLimitedEntriesIfNeeded(for: key.translationID)
        }

        // BiblePassageKey is Hashable, so we can use it in dict lookup like this
        if let existingCacheHit = loadedBiblePassageCache[key] {
            // we have a cached match; return it immediately
            switch cachePolicy {
            case .memoryOnly:
                markUsed(key)
            case .diskLimited(let maximumVerseCount):
                await recordDiskLimitedUse(of: key,
                                           verseCount: existingCacheHit.renderedPassage.verseCount,
                                           maximumVerseCount: maximumVerseCount)
            case .unlimited:
                break
            }
            return existingCacheHit
        }

        // we do not have this cached...
        // first, return existing in-flight request for this key if present
        if let existingRequest = inFlightRequests[key] {
            return try await existingRequest.value
        }

        // ... else, begin the work ourselves
        // build reference
        guard let reference = ScriptureReference(translationID: key.translationID,
                                                 bookCode: key.bookCode,
                                                 chapter: key.chapter) else {
            throw BiblePassageStoreError.invalidBiblePassageKey
        }

        // store the fetch logic as a Task so that we can add it to inFlightRequests
        // Unstructured task: independent of its awaiters
        //   Awaiting task.value does NOT pass cancellation down here
        //   Basically we don't have any C# "CancellationToken" here
        //   We do NOT need to wire this up though because other cards may be waiting on this
        //   We may need to cancel per-URL-request and only when no one wants the chapter anymore...
        let usesDiskCache = cachePolicy.storesOnDisk

        let task = Task<LoadedBiblePassage, Error> {
            // 1. disk cache (swallow read throws here)
            //    A cached passage that no longer parses (e.g. saved before its translation
            //    moved to another provider) is treated as a miss, and the fetch below replaces it.
            if usesDiskCache,
               let cached = try? await passageCache.passage(for: key) {
                do {
                    let renderedPassage = try repository.renderedPassage(from: cached,
                                                                         translationID: reference.translationID)
                    return LoadedBiblePassage(passage: cached,
                                              renderedPassage: renderedPassage)
                } catch {
                    Self.logger.error("Cached passage failed to parse; fetching again: \(error.localizedDescription)")
                }
            }

            // 2. network; parse with the parser for this passage's provider
            let passage = try await repository.passage(for: reference)
            let renderedPassage = try repository.renderedPassage(from: passage,
                                                                 translationID: reference.translationID)

            // cache to disk only after the passage parses
            if usesDiskCache {
                do {
                    try await passageCache.save(passage, for: key)
                } catch {
                    Self.logger.error("Unable to cache passage: \(error.localizedDescription)")
                }
            }

            return LoadedBiblePassage(passage: passage,
                                      renderedPassage: renderedPassage)
        }

        // set tracking; then clear it as soon as this function exits
        inFlightRequests[key] = task

        defer {
            inFlightRequests[key] = nil
        }

        // no need to use "await task.result" because this func already throws
        let loadedBiblePassage = try await task.value
        loadedBiblePassageCache[key] = loadedBiblePassage

        switch cachePolicy {
        case .memoryOnly(let maximumVerseCount):
            markUsed(key)
            evictLeastRecentlyUsed(translationID: key.translationID,
                                   maximumVerseCount: maximumVerseCount,
                                   keeping: key)
        case .diskLimited(let maximumVerseCount):
            await recordDiskLimitedUse(of: key,
                                       verseCount: loadedBiblePassage.renderedPassage.verseCount,
                                       maximumVerseCount: maximumVerseCount)
        case .unlimited:
            break
        }

        return loadedBiblePassage
    }

    // MARK: Functions (Private, Disk Verse Limit)

    /// Reads a translation's saved chapter list once per launch
    ///
    /// A read that fails counts as empty; the next launch reads (and cleans up) again
    private func loadDiskLimitedEntriesIfNeeded(for translationID: Translation.ID) async {
        guard diskLimitedEntries[translationID] == nil else {
            return
        }

        let load: Task<[PassageCacheEntry], Never>

        if let existingLoad = diskLimitedEntryLoads[translationID] {
            load = existingLoad
        } else {
            let passageCache = self.passageCache

            load = Task {
                do {
                    return try await passageCache.verseLimitEntries(for: translationID)
                } catch {
                    Self.logger.error("Unable to read verse-limited cache list: \(error.localizedDescription)")
                    return []
                }
            }

            diskLimitedEntryLoads[translationID] = load
        }

        let entries = await load.value

        // Every waiter resumes here in no fixed order; whichever runs first stores the result
        diskLimitedEntryLoads[translationID] = nil

        if diskLimitedEntries[translationID] == nil {
            diskLimitedEntries[translationID] = entries
        }
    }

    /// Make a chapter the most recently used, drop this translation's least recently used
    /// chapters from memory and disk until its verses fit the limit, then save the list
    ///
    /// The chapter just returned always stays, even if it alone is over the limit.
    private func recordDiskLimitedUse(of key: BiblePassageKey,
                                      verseCount: Int,
                                      maximumVerseCount: Int) async {
        var entries = diskLimitedEntries[key.translationID] ?? []
        entries.removeAll { $0.key == key }
        entries.append(PassageCacheEntry(key: key, verseCount: verseCount))

        var cachedVerseCount = entries.reduce(0) { total, entry in total + entry.verseCount }
        var evictedKeys: [BiblePassageKey] = []

        while cachedVerseCount > maximumVerseCount,
              let oldestEntry = entries.first,
              oldestEntry.key != key {
            entries.removeFirst()
            cachedVerseCount -= oldestEntry.verseCount
            evictedKeys.append(oldestEntry.key)
            loadedBiblePassageCache[oldestEntry.key] = nil
        }

        diskLimitedEntries[key.translationID] = entries

        // Save the list before deleting files: if the app quits in between, the next
        // launch's read deletes the files the list no longer includes
        do {
            try await passageCache.saveVerseLimitEntries(entries, for: key.translationID)
        } catch {
            Self.logger.error("Unable to save verse-limited cache list: \(error.localizedDescription)")
        }

        for evictedKey in evictedKeys {
            do {
                try await passageCache.removePassage(for: evictedKey)
            } catch {
                Self.logger.error("Unable to remove evicted passage: \(error.localizedDescription)")
            }
        }
    }

    // MARK: Functions (Private, Verse Limit)

    /// Move a key to the most recently used end
    private func markUsed(_ key: BiblePassageKey) {
        memoryOnlyKeysByLastUse.removeAll { $0 == key }
        memoryOnlyKeysByLastUse.append(key)
    }

    /// Drop this translation's least recently used passages until its verses fit the limit
    ///
    /// The passage just returned (keeping) always stays, even if it alone is over the limit.
    private func evictLeastRecentlyUsed(translationID: Translation.ID,
                                        maximumVerseCount: Int,
                                        keeping keptKey: BiblePassageKey) {
        var translationKeys = memoryOnlyKeysByLastUse.filter { $0.translationID == translationID }

        var cachedVerseCount = translationKeys.reduce(0) { total, key in
            total + (loadedBiblePassageCache[key]?.renderedPassage.verseCount ?? 0)
        }

        while cachedVerseCount > maximumVerseCount,
              let oldestKey = translationKeys.first,
              oldestKey != keptKey {
            translationKeys.removeFirst()
            memoryOnlyKeysByLastUse.removeAll { $0 == oldestKey }

            if let evictedPassage = loadedBiblePassageCache.removeValue(forKey: oldestKey) {
                cachedVerseCount -= evictedPassage.renderedPassage.verseCount
            }
        }
    }
}

/// BiblePassageStore error definitions
enum BiblePassageStoreError: Error {
    /// Thrown when passage() is given an invalid key which, i.e., cannot be used in the
    /// creation of a valid ScriptureReference
    case invalidBiblePassageKey
}
