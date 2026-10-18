//
//  LibraryOrderTests.swift
//  SwiftBibleTests
//
//  Created by Brandon Thomas on 2026-10-09.
//

import Foundation
import Testing
@testable import SwiftBible

struct LibraryOrderTests {

    /// Fake book-position lookup; anything missing (e.g. "REV") is unknown
    private let positions = ["GEN": 0, "EXO": 1]

    /// Newest annotations come first
    @Test func dateAddedDescendingSortsNewestFirst() {
        let oldest = makeAnnotation(createdAt: Date(timeIntervalSince1970: 100))
        let middle = makeAnnotation(createdAt: Date(timeIntervalSince1970: 200))
        let newest = makeAnnotation(createdAt: Date(timeIntervalSince1970: 300))

        let order = LibraryOrder(sortOption: .dateAddedDescending)
        let sorted = order.sorted(annotations: [middle, oldest, newest],
                                  bookPosition: { positions[$0.bookCode] })

        #expect(sorted == [newest, middle, oldest])
    }

    /// Oldest annotations come first
    @Test func dateAddedAscendingSortsOldestFirst() {
        let oldest = makeAnnotation(createdAt: Date(timeIntervalSince1970: 100))
        let middle = makeAnnotation(createdAt: Date(timeIntervalSince1970: 200))
        let newest = makeAnnotation(createdAt: Date(timeIntervalSince1970: 300))

        let order = LibraryOrder(sortOption: .dateAddedAscending)
        let sorted = order.sorted(annotations: [middle, newest, oldest],
                                  bookPosition: { positions[$0.bookCode] })

        #expect(sorted == [oldest, middle, newest])
    }

    /// Canonical position wins over alphabetical (GEN before EXO); unknown books go last
    @Test func bookOrderAscendingUsesBookPositionWithUnknownLast() {
        let genesis = makeAnnotation(bookCode: "GEN")
        let exodus = makeAnnotation(bookCode: "EXO")
        let revelation = makeAnnotation(bookCode: "REV")

        let order = LibraryOrder(sortOption: .bookOrderAscending)
        let sorted = order.sorted(annotations: [revelation, exodus, genesis],
                                  bookPosition: { positions[$0.bookCode] })

        #expect(sorted == [genesis, exodus, revelation])
    }

    /// Reverse canonical position; unknown books still go last
    @Test func bookOrderDescendingReversesBookPositionWithUnknownLast() {
        let genesis = makeAnnotation(bookCode: "GEN")
        let exodus = makeAnnotation(bookCode: "EXO")
        let revelation = makeAnnotation(bookCode: "REV")

        let order = LibraryOrder(sortOption: .bookOrderDescending)
        let sorted = order.sorted(annotations: [genesis, revelation, exodus],
                                  bookPosition: { positions[$0.bookCode] })

        #expect(sorted == [exodus, genesis, revelation])
    }

    /// Same book falls back to chapter order
    @Test func bookOrderAscendingSortsSameBookByChapter() {
        let chapterOne = makeAnnotation(chapter: 1)
        let chapterTwo = makeAnnotation(chapter: 2)
        let chapterThree = makeAnnotation(chapter: 3)

        let order = LibraryOrder(sortOption: .bookOrderAscending)
        let sorted = order.sorted(annotations: [chapterThree, chapterOne, chapterTwo],
                                  bookPosition: { positions[$0.bookCode] })

        #expect(sorted == [chapterOne, chapterTwo, chapterThree])
    }

    /// Same chapter falls back to verse order
    @Test func bookOrderAscendingSortsSameChapterByVerse() {
        let verseOne = makeAnnotation(startVerse: 1)
        let verseFive = makeAnnotation(startVerse: 5)
        let verseTen = makeAnnotation(startVerse: 10)

        let order = LibraryOrder(sortOption: .bookOrderAscending)
        let sorted = order.sorted(annotations: [verseTen, verseOne, verseFive],
                                  bookPosition: { positions[$0.bookCode] })

        #expect(sorted == [verseOne, verseFive, verseTen])
    }

    /// When grouping by book, canonical book order is respected for section orders (group sorts),
    /// while **annotation** sort is untouched
    ///
    /// - Unknown books go last
    /// - Titles fall back to book code
    @Test func groupingByBookRespectsCanonicalOrder() {
        let genesis1 = makeAnnotation(bookCode: "GEN", chapter: 1)
        let genesis2 = makeAnnotation(bookCode: "GEN", chapter: 2)
        let exodus1 = makeAnnotation(bookCode: "EXO", chapter: 1)
        let exodus2 = makeAnnotation(bookCode: "EXO", chapter: 2)
        let revelation3 = makeAnnotation(bookCode: "REV", chapter: 3)

        let order = LibraryOrder(groupOption: .book)
        let grouped = order.grouped(annotations: [genesis2, revelation3, exodus2, exodus1, genesis1],
                                    bookPosition: { positions[$0.bookCode] },
                                    bookName: { _ in nil },
                                    translationAbbreviation: { _ in nil })

        #expect(
            grouped == [
                .init(
                    id: "GEN",
                    title: "GEN",
                    annotations: [genesis2, genesis1]
                ),
                .init(
                    id: "EXO",
                    title: "EXO",
                    annotations: [exodus2, exodus1]
                ),
                .init(
                    id: "REV",
                    title: "REV",
                    annotations: [revelation3]
                )
            ]
        )
    }

    // MARK: Helpers

    private func makeAnnotation(
        bookCode: String = "GEN",
        chapter: Int = 1,
        startVerse: Int = 1,
        createdAt: Date = Date(timeIntervalSince1970: 0)
    ) -> VerseAnnotation {
        VerseAnnotation(id: UUID(),
                        translationID: 1234,
                        bookCode: bookCode,
                        chapter: chapter,
                        startVerse: startVerse,
                        endVerse: nil,
                        content: .note("Note"),
                        createdAt: createdAt)
    }
}
