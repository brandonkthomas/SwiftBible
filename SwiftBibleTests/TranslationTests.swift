//
//  TranslationTests.swift
//  SwiftBibleTests
//
//  Created by Brandon Thomas on 6/26/26.
//

import Testing
@testable import SwiftBible

struct TranslationTests {

    /// Translation exposes a stable identity thru "id" property
    @Test func exposesStableIdentity() {
        let translation = Translation(id: 1849,
                                      abbreviation: "TPT",
                                      title: "The Passion Translation",
                                      languageTag: "en",
                                      license: "Copyright (c) 2026 by BroadStreet Publishing. ",
                                      promotionalText: nil,
                                      availableBookCodes: ["GEN", "EXO", "LEV"])

        #expect(translation.id == 1849)
    }

    /// Two identical Translations equal each other
    @Test func identicalTranslationsEqual() {
        let translation1 = Translation(id: 1849,
                                       abbreviation: "TPT",
                                       title: "The Passion Translation",
                                       languageTag: "en",
                                       license: "Copyright (c) 2026 by BroadStreet Publishing.",
                                       promotionalText: nil,
                                       availableBookCodes: ["GEN", "EXO", "LEV"])
        let translation2 = Translation(id: 1849,
                                       abbreviation: "TPT",
                                       title: "The Passion Translation",
                                       languageTag: "en",
                                       license: "Copyright (c) 2026 by BroadStreet Publishing.",
                                       promotionalText: nil,
                                       availableBookCodes: ["GEN", "EXO", "LEV"])

        #expect(translation1 == translation2)
    }

    /// Two Translations with different "id" properties do not equal each other
    @Test func differentTranslationIdsDoNotEqual() {
        let translation1 = Translation(id: 1849,
                                       abbreviation: "TPT",
                                       title: "The Passion Translation",
                                       languageTag: "en",
                                       license: "Copyright (c) 2026 by BroadStreet Publishing.",
                                       promotionalText: nil,
                                       availableBookCodes: ["GEN", "EXO", "LEV"])
        let translation2 = Translation(id: 1234,
                                       abbreviation: "TPT",
                                       title: "The Passion Translation",
                                       languageTag: "en",
                                       license: "Copyright (c) 2026 by BroadStreet Publishing.",
                                       promotionalText: nil,
                                       availableBookCodes: ["GEN", "EXO", "LEV"])

        #expect(translation1 != translation2)
    }
}
