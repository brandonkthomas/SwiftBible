//
//  YouVersionBibleIndexResponse.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 6/28/26.
//

/// Maps to "~/v1/bibles/{bible\_id\_path}/index"
struct YouVersionBibleIndexResponse: Decodable {
    let textDirection: String
    let books: [YouVersionBook]

    // aliases for JSONDecoder
    enum CodingKeys: String, CodingKey {
        case textDirection = "text_direction"
        case books
    }

    /// Map YouVersion book/chapter objects to SwiftBible Book/Chapter
    func booksForApp() -> [Book] {
        return self.books.compactMap { $0.bookForApp() }
    }
}

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

/// YouVersion chapter object + SwiftBible mapper
struct YouVersionChapter: Decodable {
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
    func chapterForApp(bookID: String) -> Chapter? {
        guard let idString = self.id.split(separator: ".").last?.description,
              let id = Int(idString) else {
            return nil
        }

        return Chapter(
            id: self.passageID,
            number: id,
            bookID: bookID,
            displayName: self.title
        )
    }
}
