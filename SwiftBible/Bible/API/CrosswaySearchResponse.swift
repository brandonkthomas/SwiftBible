//
//  CrosswaySearchResponse.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 2026-11-21.
//

import Foundation

/// Maps to "~/v3/passage/search?q={}"
/// Optional params: page-size, page
///
/// See https://api.esv.org/docs/passage-search/
///
/// Returns:
/// {
///   "page": 1,
///   "total_results": 3,
///   "results": [
///       {
///           "reference": "Numbers 11:4",
///           "content": "Now the rabble that was among them had a strong craving. And ..."
///       },
///       {
///           "reference": "Job 30:12",
///           "content": "On my right hand the rabble rise; they push away my feet; ..."
///       },
///       {
///           "reference": "Acts 17:5",
///           "content": "But the Jews were jealous, and taking some wicked men ..."
///       }
///   ],
///   "total_pages": 1
/// }
nonisolated struct CrosswaySearchResponse: Decodable {
    let page: Int
    let totalResults: Int
    let results: [CrosswaySearchVerseResponse]
    let totalPages: Int

    // aliases for JSONDecoder
    enum CodingKeys: String, CodingKey {
        case page
        case totalResults = "total_results"
        case results
        case totalPages = "total_pages"
    }

    /// Map search results to our ScriptureSearchPage
    func searchPage() -> ScriptureSearchPage {
        var results: [ScriptureSearchResult] = []

        // Loop over + map results
        for result in self.results {
            // ensure valid reference format
            guard let spaceIndex = result.reference.lastIndex(of: " ") else {
                continue
            }

            // ensure valid book
            let bookDisplayName = result.reference[..<spaceIndex] // "1 John" -- ..<i means start => i, excluding i
            let book = BookDefaults.defaultBooksEsv
                .first { $0.displayName.lowercased() == bookDisplayName.lowercased() }
            guard let book else { continue }
            let bookCode = book.code

            // ensure valid chapter/verse
            let chapterAndVerse = result.reference[result.reference.index(after: spaceIndex)...] // "3:16"
            var chapter: Int = 0
            var verse: Int = 0

            if chapterAndVerse.contains(":") {
                // i.e. "Genesis 3:1"
                let parts = chapterAndVerse.split(separator: ":")

                guard parts.count == 2,
                      let chapterCalc = Int(parts[0]),
                      let verseCalc = Int(parts[1]) else { continue }

                chapter = chapterCalc
                verse = verseCalc
            } else if book.chapters.count == 1 {
                // i.e. "Genesis 1"
                chapter = 1
                guard let verseCalc = Int(chapterAndVerse) else { continue }
                verse = verseCalc
            } else {
                // i.e. "Genesis 3"; skip this
                continue
            }

            results.append(ScriptureSearchResult(
                translationID: CrosswayBibleRepository.esvTranslationID,
                bookCode: bookCode,
                chapter: chapter,
                verseRange: verse...verse,
                snippet: result.content.trimmingCharacters(in: .whitespacesAndNewlines)
            ))
        }

        // TODO: loop again to consolidate immediately-adjacent verse ranges in same book/chapter
        // into one result

        // Return final listing
        let nextPage = page < totalPages ? ScriptureSearchCursor.pageNumber(page + 1) : nil
        return ScriptureSearchPage(results: results,
                                   nextCursor: nextPage,
                                   suggestions: [],
                                   searchedInsteadFor: nil,
                                   intent: .unknown)
    }
}

/// Verse reference response param -- see CrosswaySearchResponse
nonisolated struct CrosswaySearchVerseResponse: Decodable {
    let reference: String
    let content: String
}
