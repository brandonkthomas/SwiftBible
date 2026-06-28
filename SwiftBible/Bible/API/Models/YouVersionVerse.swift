//
//  YouVersionVerse.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 6/28/26.
//

/// YouVersion verse object + SwiftBible mapper
nonisolated struct YouVersionVerse: Decodable {
    let id: String
    let passageID: String
    let title: String

    // aliases for JSONDecoder
    enum CodingKeys: String, CodingKey {
        case id
        case passageID = "passage_id"
        case title
    }

    /// Map YouVersion chapter object to SwiftBible Chapter
    func verseForApp(chapterID: String,
                     bookID: String) -> Verse? {
        guard let idString = self.id.split(separator: ".").last?.description,
              let id = Int(idString) else {
            return nil
        }

        return Verse(
            id: self.passageID,
            number: id,
            chapterID: chapterID,
            bookID: bookID,
            displayName: self.title)
    }
}
