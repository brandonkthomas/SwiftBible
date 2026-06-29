//
//  YouVersionBibleCollectionResponseTests.swift
//  SwiftBibleTests
//
//  Created by Brandon Thomas on 6/28/26.
//

import Foundation
import Testing
@testable import SwiftBible

struct YouVersionBibleCollectionResponseTests {

    private var collectionResponse: String = """
{
    "data": [
      {
        "id": 12,
        "abbreviation": "ASV",
        "promotional_content": null,
        "copyright": "Copyright (c) 2026 Publishing Company",
        "info": null,
        "publisher_url": null,
        "language_tag": "en",
        "localized_abbreviation": "ASVL",
        "localized_title": "American Standard Version",
        "title": "American Standard Version",
        "books": [
          "GEN",
          "EXO",
          "LEV"
        ],
        "youversion_deep_link": "https://www.bible.com/versions/12",
        "organization_id": null
      },
      {
        "id": 42,
        "abbreviation": "CPDV",
        "promotional_content": null,
        "copyright": null,
        "info": null,
        "publisher_url": null,
        "language_tag": "en",
        "localized_abbreviation": "CPDV",
        "localized_title": "Catholic Public Domain Version",
        "title": "Catholic Public Domain Version",
        "books": [
          "GEN",
          "EXO",
          "LEV"
        ],
        "youversion_deep_link": "https://www.bible.com/versions/42",
        "organization_id": null
      }
    ],
    "next_page_token": null,
    "total_size": 15
  }
"""

    /// Attempt to parse test JSON via YouVersionBibleCollectionResponse mapping
    @Test func mapperFunctionsSucceed() {
        guard let responseData: Data = collectionResponse.data(using: .utf8) else {
            #expect(Bool(false), "Could not parse `collectionResponse` as UTF-8 encoded data")
            return
        }

        do {
            let jsonDecoder: JSONDecoder = .init()
            let decoded: YouVersionBibleCollectionResponse = try jsonDecoder.decode(YouVersionBibleCollectionResponse.self,
                                                                                    from: responseData)

            let translations: [Translation] = decoded.translationsForApp()

            guard let firstTranslation = translations.first else {
                #expect(Bool(false), "Could not parse first book")
                return
            }

            #expect(!translations.isEmpty)
            #expect(firstTranslation.id == 12)
            #expect(firstTranslation.availableBookCodes == ["GEN", "EXO", "LEV"])
            #expect(firstTranslation.license == "Copyright (c) 2026 Publishing Company")
            #expect(firstTranslation.abbreviation == "ASVL")
        } catch {
            #expect(Bool(false), "Failed to decode `collectionResponse`: \(error.localizedDescription)")
        }
    }

}
