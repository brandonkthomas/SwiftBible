//
//  YouVersionBibleIndexResponse.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 6/28/26.
//

/// Maps to "~/v1/bibles/{bible\_id\_path}/index"
nonisolated struct YouVersionBibleIndexResponse: Decodable {
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
