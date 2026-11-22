//
//  BibleRepository.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 6/27/26.
//

/// Implementations for Bible translation/index API access
protocol BibleRepository {
    /// Returns all available translations (optionally filtered by a given language; i.e. "en")
    func translations(languageTag: String?) async throws -> [Translation]

    /// Returns translation full details / nil when translations() already had them all
    ///
    /// YouVersion's /v1/bibles list returns empty copyright
    /// Use /v1/bibles/{id} instead
    func translationDetail(for translationID: Translation.ID) async throws -> Translation?

    /// Returns all available books for a given translation w/ canon and individual chapters
    func books(for translationID: Translation.ID) async throws -> [Book]

    /// Retrieves HTML passage content for the selected reference
    func passage(for reference: ScriptureReference) async throws -> Passage

    /// Parses a passage this repository returned into paragraphs and footnotes
    ///
    /// Each provider's HTML needs its own parser. translationID lets
    /// RoutingBibleRepository send the passage to the provider that fetched it.
    func renderedPassage(from passage: Passage,
                         translationID: Translation.ID) throws -> RenderedPassage

    /// How BiblePassageStore may cache this provider's passages for a translation
    func passageCachePolicy(for translationID: Translation.ID) -> PassageCachePolicy

    /// Does the requested translation support search results?
    func supportsSearch(translationID: Translation.ID) -> Bool

    /// Search one translation's verses for a text query
    ///
    /// exactText: search the text as typed, without the provider's spelling correction
    /// (YouVersion corrects typos unless asked not to; ESV never corrects)
    func searchVerses(_ query: String,
                      translationID: Translation.ID,
                      cursor: ScriptureSearchCursor?,
                      exactText: Bool) async throws -> ScriptureSearchPage
}

extension BibleRepository {
    /// Default: nil (translations() already includes everything)
    func translationDetail(for translationID: Translation.ID) async throws -> Translation? {
        nil
    }

    /// Default: YouVersion passage HTML
    func renderedPassage(from passage: Passage,
                         translationID: Translation.ID) throws -> RenderedPassage {
        try PassageHTMLParser().parse(html: passage.htmlContent)
    }

    /// Default: no caching limits
    func passageCachePolicy(for translationID: Translation.ID) -> PassageCachePolicy {
        .unlimited
    }

    /// Default: false
    func supportsSearch(translationID: Translation.ID) -> Bool {
        false
    }

    /// Default: throw .unsupportedTranslation
    func searchVerses(_ query: String,
                      translationID: Translation.ID,
                      cursor: ScriptureSearchCursor?,
                      exactText: Bool) async throws -> ScriptureSearchPage {
        throw ScriptureSearchError.unsupportedTranslation
    }

    /// A normal search (spelling correction allowed)
    func searchVerses(_ query: String,
                      translationID: Translation.ID,
                      cursor: ScriptureSearchCursor?) async throws -> ScriptureSearchPage {
        try await searchVerses(query, translationID: translationID, cursor: cursor, exactText: false)
    }
}

enum BibleRepositoryError: Error {
    case invalidRequestURL
    case invalidTranslation
    case invalidBook
    case responseParsingError
    case internalError(String)
}
