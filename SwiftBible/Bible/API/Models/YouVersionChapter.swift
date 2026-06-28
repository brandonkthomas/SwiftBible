//
//  YouVersionChapter.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 6/28/26.
//

/// YouVersion chapter object + SwiftBible mapper
struct YouVersionChapter: Decodable {
    let id: String
    let passageID: String
    let title: String
    let verses: [YouVersionVerse]

    // aliases for JSONDecoder
    enum CodingKeys: String, CodingKey {
        case id
        case passageID = "passage_id"
        case title
        case verses
    }

    /// Map YouVersion chapter object to SwiftBible Chapter
    func chapterForApp(bookID: String) -> Chapter? {
        guard let idString = self.id.split(separator: ".").last?.description,
              let id = Int(idString) else {
            return nil
        }

        // compactMap skips nil
        let verses = self.verses.compactMap {
            $0.verseForApp(chapterID: self.passageID,
                           bookID: bookID)
        }

        return Chapter(
            id: self.passageID,
            number: id,
            bookID: bookID,
            displayName: self.title,
            verses: verses)
    }
}
