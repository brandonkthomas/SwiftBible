//
//  YouVersionBible.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 6/28/26.
//

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
            license: self.copyright,
            promotionalText: self.promotionalContent,
            availableBookCodes: self.books)
    }
}
