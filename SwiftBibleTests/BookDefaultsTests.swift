//
//  BookDefaultsTests.swift
//  SwiftBibleTests
//
//  Created by Brandon Thomas on 2026-11-02.
//

import Testing
@testable import SwiftBible

struct BookDefaultsTests {

    /// Ensure book and chapter totals match the 66-book canon, split by testament
    @Test func totalsByTestament() {
        let oldTestament = BookDefaults.defaultBooks.filter { $0.canon == .oldTestament }
        let newTestament = BookDefaults.defaultBooks.filter { $0.canon == .newTestament }

        #expect(BookDefaults.defaultBooks.count == 66)
        #expect(oldTestament.count == 39)
        #expect(newTestament.count == 27)

        #expect(oldTestament.reduce(0) { $0 + $1.chapters.count } == 929)
        #expect(newTestament.reduce(0) { $0 + $1.chapters.count } == 260)
    }

    /// Spot check chapter counts, including the longest (PSA) and single-chapter (OBA) books
    @Test(arguments: [
        ("GEN", 50),
        ("PSA", 150),
        ("OBA", 1),
        ("REV", 22)
    ])
    func chapterCount(bookCode: String, expected: Int) throws {
        let book = try #require(BookDefaults.defaultBooks.first { $0.code == bookCode })
        #expect(book.chapters.count == expected)
    }

    /// Ensure each book's index matches BibleCatalogStore's canonical ordering
    @Test func indexMatchesCatalogBookPosition() {
        for (index, book) in BookDefaults.defaultBooks.enumerated() {
            #expect(BibleCatalogStore.bookPosition(for: book.code) == index, "\(book.code)")
        }
    }

    /// Ensure chapter IDs use the "REV.1" format that ScriptureReference.passageID and ReaderStore depend on
    @Test func revelationChapterIDs() throws {
        let revelation = try #require(BookDefaults.defaultBooks.first { $0.code == "REV" })
        #expect(revelation.chapters.first?.id == "REV.1")
        #expect(revelation.chapters.last?.id == "REV.22")
    }
}
