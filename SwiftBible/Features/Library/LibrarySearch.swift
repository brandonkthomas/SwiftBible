//
//  LibrarySearch.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 2026-11-21.
//

import Foundation

///
nonisolated struct LibrarySearch {

    // MARK: Properties

    /// Search query
    let query: String

    // MARK: Functions

    /// Searches given annotations for a given string query
    func results(in annotations: [VerseAnnotation],
                 passageLabel: (VerseAnnotation) -> String,
                 translationAbbreviation: (VerseAnnotation) -> String?) -> [VerseAnnotation] {
        // query cleanup
        let cleanedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedQuery.isEmpty else { return [] }

        // Collect all annotation fields up-front, then check against query at the end
        // Keep if any of content (excl. highlight colors), passage label, or translation abbreviation matches;
        // keep original order
        return annotations.filter { annotation in
            // field: passage label
            var fields = [passageLabel(annotation)]
            // field: translation abbreviation
            if let abbreviation = translationAbbreviation(annotation) {
                fields.append(abbreviation)
            }
            // field: annotation content (note/tags)
            switch annotation.content {
            case .note(let text): fields.append(text)
            case .tags(let tags): fields += tags
            case .highlight(_): break
            }
            // do any of the annotation's fields contain our query?
            return fields.contains { normalized($0).localizedStandardContains(cleanedQuery) }
        }
    }

    /// Treats en/em dashes as hyphens so "23:1-3" matches the label "23:1–3"
    private func normalized(_ text: String) -> String {
        text.replacingOccurrences(of: "[–—]",
                                  with: "-",
                                  options: .regularExpression)
    }
}
