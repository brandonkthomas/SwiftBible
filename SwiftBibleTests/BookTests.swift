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
        let book = Book(id: "GEN",
                        code: "GEN",
                        displayName: "Genesis",
                        canon: Canon.oldTestament,
                        chapters: [1,2,3])

        #expect(book.id == "GEN")
    }

    /// Two identical Books equal each other
    @Test func identicalBooksEqual() {
        let book1 = Book(id: "GEN",
                         code: "GEN",
                         displayName: "Genesis",
                         canon: Canon.oldTestament,
                         chapters: [1,2,3])
        let book2 = Book(id: "GEN",
                         code: "GEN",
                         displayName: "Genesis",
                         canon: Canon.oldTestament,
                         chapters: [1,2,3])

        #expect(book1 == book2)
    }

    /// Books produce their chapter numbers in order
    @Test func bookChaptersExposedInOrder() {
        let book = Book(id: "GEN",
                        code: "GEN",
                        displayName: "Genesis",
                        canon: Canon.oldTestament,
                        chapters: [1,2,3])

        #expect(book.chapters == [1,2,3])
    }
}
