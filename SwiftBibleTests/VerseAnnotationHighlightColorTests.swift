//
//  VerseAnnotationHighlightColorTests.swift
//  SwiftBibleTests
//
//  Created by Brandon Thomas on 2026-11-16.
//

import Foundation
import Testing
@testable import SwiftBible

/// SwiftData stores `highlightColor` as its raw string ("pink") and decodes it through `Codable`.
/// A raw value this build does not know (a color added in a later build, synced over iCloud)
/// must not crash the fetch.
struct VerseAnnotationHighlightColorTests {

    /// every current case still decodes to itself
    @Test(arguments: VerseAnnotationHighlightColor.allCases)
    func knownRawValueDecodes(color: VerseAnnotationHighlightColor) throws {
        let data = Data("[\"\(color.rawValue)\"]".utf8)

        let decoded = try JSONDecoder().decode([VerseAnnotationHighlightColor].self, from: data)

        #expect(decoded == [color])
    }

    /// an unknown raw value decodes to yellow instead of throwing
    @Test func unknownRawValueFallsBackToYellow() throws {
        let data = Data("[\"orange\"]".utf8)

        let decoded = try JSONDecoder().decode([VerseAnnotationHighlightColor].self, from: data)

        #expect(decoded == [.yellow])
    }

    /// encoding is unchanged: a plain raw string, which is what the store column already holds
    @Test func encodesAsRawString() throws {
        let data = try JSONEncoder().encode([VerseAnnotationHighlightColor.pink])

        #expect(String(decoding: data, as: UTF8.self) == "[\"pink\"]")
    }
}
