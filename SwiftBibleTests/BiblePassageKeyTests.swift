//
//  BiblePassageKeyTests.swift
//  SwiftBibleTests
//
//  Created by Brandon Thomas on 2026-09-02.
//

import Testing
@testable import SwiftBible

struct BiblePassageKeyTests {

    /// Two keys with identical fields compare equal
    @Test func identicalKeysCompareEqual() async throws {
        let key1 = BiblePassageKey(translationID: 123,
                                   bookCode: "GEN",
                                   chapter: 1)

        let key2 = BiblePassageKey(translationID: 123,
                                   bookCode: "GEN",
                                   chapter: 1)

        #expect(key1 == key2)
    }

    /// Putting identical keys into a Set produces one entry
    @Test func identicalKeysIntoSetProducesSingleEntry() async throws {
        let key1 = BiblePassageKey(translationID: 123,
                                   bookCode: "GEN",
                                   chapter: 1)

        let key2 = BiblePassageKey(translationID: 123,
                                   bookCode: "GEN",
                                   chapter: 1)

        #expect(Set([key1, key2]).count == 1)
    }

    /// The same book/chapter in two translations produces two entries
    @Test func uniqueTranslationsRemainDistinct() async throws {
        let key1 = BiblePassageKey(translationID: 123,
                                   bookCode: "GEN",
                                   chapter: 1)

        let key2 = BiblePassageKey(translationID: 456,
                                   bookCode: "GEN",
                                   chapter: 1)

        #expect(key1 != key2)
        #expect(Set([key1, key2]).count == 2)
    }

    /// The same translation/chapter in two books produces two entries
    @Test func uniqueBookCodesRemainDistinct() async throws {
        let key1 = BiblePassageKey(translationID: 123,
                                   bookCode: "GEN",
                                   chapter: 1)

        let key2 = BiblePassageKey(translationID: 123,
                                   bookCode: "EXO",
                                   chapter: 1)

        #expect(key1 != key2)
        #expect(Set([key1, key2]).count == 2)
    }

    /// The same translation/book in two chapters produces two entries
    @Test func uniqueChaptersRemainDistinct() async throws {
        let key1 = BiblePassageKey(translationID: 123,
                                   bookCode: "GEN",
                                   chapter: 1)

        let key2 = BiblePassageKey(translationID: 123,
                                   bookCode: "GEN",
                                   chapter: 2)

        #expect(key1 != key2)
        #expect(Set([key1, key2]).count == 2)
    }
}
