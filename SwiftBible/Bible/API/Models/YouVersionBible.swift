//
//  YouVersionBible.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 6/28/26.
//

import Foundation

/// YouVersion bible object + SwiftBible Translation mapper
nonisolated struct YouVersionBible: Decodable {
    let id: Int
    let abbreviation: String
    let localizedAbbreviation: String?
    let title: String
    let localizedTitle: String?
    let languageTag: String
    let copyright: String?
    let promotionalContent: String?
    let books: [String]

    // aliases for JSONDecoder
    enum CodingKeys: String, CodingKey {
        case id
        case abbreviation
        case localizedAbbreviation = "localized_abbreviation"
        case title
        case localizedTitle = "localized_title"
        case languageTag = "language_tag"
        case copyright
        case promotionalContent = "promotional_content"
        case books
    }

    /// Map YouVersion translation object to SwiftBible Translation
    func translationForApp() -> Translation {
        return Translation(
            id: self.id,
            abbreviation: self.localizedAbbreviation ?? self.abbreviation,
            title: self.localizedTitle ?? self.title,
            languageTag: self.languageTag,
            license: Self.unquoted(self.copyright),
            promotionalText: Self.unquoted(self.promotionalContent),
            availableBookCodes: self.books)
    }

    /// YouVersion wraps some values in literal quotes ("\"The Holy Bible...\"");
    /// return the text without them, or nil when nothing is left
    private static func unquoted(_ value: String?) -> String? {
        guard var text = value?.trimmingCharacters(in: .whitespacesAndNewlines) else {
            return nil
        }

        if text.count >= 2,
           text.hasPrefix("\""),
           text.hasSuffix("\"") {
            text = String(text.dropFirst().dropLast())
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return text.isEmpty ? nil : text
    }
}
