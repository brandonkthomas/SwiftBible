//
//  YouVersionPassageResponse.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 6/30/26.
//

/// Maps to "~/v1/bibles/{bible\_id\_path}/passages/{passage\_id\_path}"
nonisolated struct YouVersionPassageResponse: Decodable {
    let id: String
    let htmlContent: String
    let reference: String

    // aliases for JSONDecoder
    enum CodingKeys: String, CodingKey {
        case id
        case htmlContent = "content"
        case reference
    }

    func passageForApp() -> Passage {
        Passage(id: id,
                reference: reference,
                htmlContent: htmlContent)
    }
}
