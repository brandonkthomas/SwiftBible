//
//  BiblePassageStore.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 2026-09-13.
//

import Foundation

/// Ownership model for loaded Passages
///
/// On request, if cached, return; else load > cache > return
///
/// Cache itself is not directly accessible; use public entry point functions
final class BiblePassageStore {

    // MARK: Properties (Private)

    /// Used for loading passages if they do not exist in the cache
    private let repository: any BibleRepository

    /// Stores any cached values; NOT externally readable (must use public overloads)
    private var cache: [BiblePassageKey: LoadedBiblePassage] = [:]

    // MARK: Init

    init(repository: any BibleRepository) {
        self.repository = repository
    }

    // MARK: Functions

    /// Retrieve a passage by ID.
    /// If it exists in cache, return; else, load + persist to cache + return
    func passage(for key: BiblePassageKey) async throws -> LoadedBiblePassage {
        // BiblePassageKey is Hashable, so we can use it in dict lookup like this
        if let existingCacheHit = cache[key] {
            // we have a cached match; return it immediately
            return existingCacheHit
        } else {
            // we do not have this cached...
            // build reference
            guard let reference = ScriptureReference(translationID: key.translationID,
                                                     bookCode: key.bookCode,
                                                     chapter: key.chapter) else {
                throw BiblePassageStoreError.invalidBiblePassageKey
            }

            // retrieve passage
            let passage = try await repository.passage(for: reference)

            // parse HTML
            let parser = PassageHTMLParser()
            let renderedPassage = try parser.parse(html: passage.htmlContent)

            // build LoadedBiblePassage; persist to cache; return
            let loadedBiblePassage = LoadedBiblePassage.init(passage: passage,
                                                             renderedPassage: renderedPassage)
            cache[key] = loadedBiblePassage
            return loadedBiblePassage
        }
    }
}

/// BiblePassageStore error definitions
enum BiblePassageStoreError: Error {
    /// Thrown when passage() is given an invalid key which, i.e., cannot be used in the
    /// creation of a valid ScriptureReference
    case invalidBiblePassageKey
}
