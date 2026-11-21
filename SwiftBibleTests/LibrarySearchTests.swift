//
//  LibrarySearchTests.swift
//  SwiftBibleTests
//

import Foundation
import Testing
@testable import SwiftBible

/// Search step 6: matching saved annotations against typed text, offline, without verse text
///
/// Searched: note text, tags, passage label, translation. Not highlight color (learner, 2026-11-21).
///
/// Probe 2026-11-21: `localizedStandardContains` ignores case and accents ("Café" contains "CAFE"),
/// but not dashes: passage labels use an en dash ("Psalms 23:1–3") while people type a hyphen.
@MainActor
struct LibrarySearchTests {

    /// Labels the Library already shows for every test annotation
    private let passageLabel = "Psalms 23:1–3"
    private let translationAbbreviation = "NIV"

    /// Each searchable part of an annotation can match on its own
    @Test(arguments: [
        (AnnotationContent.note("Remember the Sabbath"), "sabbath"),   // note text
        (.tags(["Hope", "Grace"]), "grace"),                            // a tag
        (.note("unrelated"), "psalms 23"),                              // passage label
        (.note("unrelated"), "niv"),                                    // translation
        (.note("unrelated"), "23:1-3")                                  // typed hyphen vs label's en dash
    ])
    func eachFieldMatches(content: AnnotationContent, query: String) {
        let annotation = makeAnnotation(content)

        #expect(search(query, in: [annotation]) == [annotation])
    }

    /// Case and accents don't matter
    @Test func caseAndAccentsAreIgnored() {
        let annotation = makeAnnotation(.note("Café in Capernaum"))

        #expect(search("CAFE", in: [annotation]) == [annotation])
    }

    /// Non-matches are left out, and matches keep the order they were given in
    @Test func keepsOrderAndDropsNonMatches() {
        let newest = makeAnnotation(.note("shepherd psalm"))
        let middle = makeAnnotation(.tags(["Faith"]))
        let oldest = makeAnnotation(.note("the good shepherd"))

        #expect(search("shepherd", in: [newest, middle, oldest]) == [newest, oldest])
    }

    /// A blank query shows nothing rather than every annotation
    @Test func blankQueryMatchesNothing() {
        let annotation = makeAnnotation(.note("anything"))

        #expect(search("   ", in: [annotation]).isEmpty)
    }

    // MARK: Helpers

    private func search(_ query: String, in annotations: [VerseAnnotation]) -> [VerseAnnotation] {
        LibrarySearch(query: query).results(in: annotations,
                                            passageLabel: { _ in passageLabel },
                                            translationAbbreviation: { _ in translationAbbreviation })
    }

    private func makeAnnotation(_ content: AnnotationContent) -> VerseAnnotation {
        VerseAnnotation(id: UUID(),
                        translationID: 111,
                        bookCode: "PSA",
                        chapter: 23,
                        startVerse: 1,
                        endVerse: 3,
                        content: content,
                        createdAt: .now)
    }
}
