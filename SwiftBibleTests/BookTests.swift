//
//  BookTests.swift
//  SwiftBibleTests
//
//  Created by Brandon Thomas on 6/26/26.
//

import Testing
@testable import SwiftBible

struct BookTests {

    /// Book exposes a stable identity thru "id" property
    @Test func exposesStableIdentity() {
        guard let book = FakeBibleRepository.defaultBooks.first else {
            #expect(Bool(false), "fixture should contain at least 1 book")
            return
        }

        #expect(book.id == "GEN")
    }

    /// Two identical Books equal each other
    @Test func identicalBooksEqual() {
        let chapter1 = Chapter(id: "GEN.1",
                               number: 1,
                               bookID: "GEN",
                               displayName: "1",
                               verses: [])
        let chapter2 = Chapter(id: "GEN.2",
                               number: 2,
                               bookID: "GEN",
                               displayName: "2",
                               verses: [])
        let chapter3 = Chapter(id: "GEN.3",
                               number: 3,
                               bookID: "GEN",
                               displayName: "3",
                               verses: [])

        let book1 = Book(id: "GEN",
                         code: "GEN",
                         displayName: "Genesis",
                         canon: Canon.oldTestament,
                         chapters: [chapter1,chapter2,chapter3])
        let book2 = Book(id: "GEN",
                         code: "GEN",
                         displayName: "Genesis",
                         canon: Canon.oldTestament,
                         chapters: [chapter1,chapter2,chapter3])

        #expect(book1 == book2)
    }

    /// Books produce their chapter numbers in order
    @Test func bookChaptersExposedInOrder() {
        let chapter1 = Chapter(id: "GEN.1",
                               number: 1,
                               bookID: "GEN",
                               displayName: "1",
                               verses: [])
        let chapter2 = Chapter(id: "GEN.2",
                               number: 2,
                               bookID: "GEN",
                               displayName: "2",
                               verses: [])
        let chapter3 = Chapter(id: "GEN.3",
                               number: 3,
                               bookID: "GEN",
                               displayName: "3",
                               verses: [])

        let book = Book(id: "GEN",
                        code: "GEN",
                        displayName: "Genesis",
                        canon: Canon.oldTestament,
                        chapters: [chapter1,chapter2,chapter3])

        #expect(book.chapters.map(\.number) == [1,2,3])
    }

    /// Books can store "deuterocanon" value i.e.
    @Test func bookCanonRetainsValues() {
        let chapter1 = Chapter(id: "GEN.1",
                               number: 1,
                               bookID: "GEN",
                               displayName: "1",
                               verses: [])
        let chapter2 = Chapter(id: "GEN.2",
                               number: 2,
                               bookID: "GEN",
                               displayName: "2",
                               verses: [])
        let chapter3 = Chapter(id: "GEN.3",
                               number: 3,
                               bookID: "GEN",
                               displayName: "3",
                               verses: [])

        let book = Book(id: "BOK",
                        code: "BOK",
                        displayName: "Book Name",
                        canon: Canon.deuterocanon,
                        chapters: [chapter1,chapter2,chapter3])

        #expect(book.canon == .deuterocanon)
    }
}
