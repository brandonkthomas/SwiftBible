//
//  YouVersionBibleCollectionResponse.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 6/28/26.
//

/// Maps to "~/v1/bibles"
nonisolated struct YouVersionBibleCollectionResponse: Decodable {
    let data: [YouVersionBible]
    let nextPageToken: String?
    let totalSize: Int?

    // aliases for JSONDecoder
    enum CodingKeys: String, CodingKey {
        case data
        case nextPageToken = "next_page_token"
        case totalSize = "total_size"
    }

    /// Map YouVersion bible objects to SwiftBible Translation
    func translationsForApp() -> [Translation] {
        return self.data.compactMap { $0.translationForApp() }
    }
}
