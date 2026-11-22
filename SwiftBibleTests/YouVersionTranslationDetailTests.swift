//
//  YouVersionTranslationDetailTests.swift
//  SwiftBibleTests
//

import Foundation
import Testing
@testable import SwiftBible

/// GET /v1/bibles/{id}: the only YouVersion response that carries copyright
///
/// Live check 2026-11-22: /v1/bibles returned copyright null for every English version;
/// /v1/bibles/111 returned the Biblica notice. The fixture below is trimmed from that response.
@MainActor
struct YouVersionTranslationDetailTests {

    @Test func detailUrlIsSingleBiblePath() throws {
        let url = try makeRepository().translationDetailUrl(for: 111)

        #expect(url.absoluteString == "https://api.youversion.com/v1/bibles/111")
    }

    /// The response is one bible object (no data wrapper); copyright maps to license
    @Test func detailResponseMapsCopyright() throws {
        let translation = try YouVersionBibleRepository.translation(fromDetail: Data(Self.nivDetailJson.utf8))

        #expect(translation.id == 111)
        #expect(translation.copyrightNotice?.hasPrefix("The Holy Bible, New International Version") == true)
        #expect(translation.promotionalText == "Biblica is the worldwide publisher of the NIV.")
    }

    /// ASV's detail has no copyright or promotional text
    @Test func detailResponseWithoutCopyrightHasNoNotice() throws {
        let translation = try YouVersionBibleRepository.translation(fromDetail: Data(Self.asvDetailJson.utf8))

        #expect(translation.copyrightNotice == nil)
    }

    // MARK: Fixtures

    private static let nivDetailJson = """
    {
      "id": 111,
      "abbreviation": "NIV11",
      "localized_abbreviation": "NIV",
      "title": "New International Version 2011",
      "localized_title": "New International Version",
      "language_tag": "en",
      "copyright": "The Holy Bible, New International Version® NIV®\\nCopyright © 1973, 1978, 1984, 2011 by Biblica, Inc.®\\nUsed by Permission of Biblica, Inc.® All rights reserved worldwide.",
      "promotional_content": "Biblica is the worldwide publisher of the NIV.",
      "info": null,
      "publisher_name": "Biblica, Inc.",
      "publisher_url": "https://www.biblica.com/yv-learn-more/",
      "youversion_deep_link": "https://www.bible.com/versions/111",
      "books": ["GEN", "EXO"]
    }
    """

    private static let asvDetailJson = """
    {
      "id": 12,
      "abbreviation": "ASV",
      "localized_abbreviation": "ASV",
      "title": "American Standard Version",
      "localized_title": "American Standard Version",
      "language_tag": "en",
      "copyright": null,
      "promotional_content": null,
      "youversion_deep_link": "https://www.bible.com/versions/12",
      "books": ["GEN"]
    }
    """

    // MARK: Helpers

    private func makeRepository() throws -> YouVersionBibleRepository {
        YouVersionBibleRepository(apiKey: "KEY",
                                  baseURL: try #require(URL(string: "https://api.youversion.com")),
                                  urlSession: .shared)
    }
}
