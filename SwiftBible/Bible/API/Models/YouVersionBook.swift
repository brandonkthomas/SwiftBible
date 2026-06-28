//
//  YouVersionBook.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 6/28/26.
//

/// YouVersion book object + SwiftBible mapper
struct YouVersionBook: Decodable {
    let id: String
    let title: String
    let fullTitle: String
    let abbreviation: String
    let canon: String
    let chapters: [YouVersionChapter]

    // aliases for JSONDecoder
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case fullTitle = "full_title"
        case abbreviation
        case canon
        case chapters
    }

    /// Map YouVersion book/chapter object to SwiftBible Book/Chapter
    func bookForApp() -> Book? {
        guard let canon = Canon.fromString(self.canon) else {
            return nil
        }

        // compactMap skips nil
        let chapters = self.chapters.compactMap { $0.chapterForApp(bookID: self.id) }

        return Book(
            id: self.id,
            code: self.id,
            displayName: self.title,
            canon: canon,
            chapters: chapters
        )
    }
}
