//
//  YouVersionBibleIndexResponseTests.swift
//  SwiftBibleTests
//
//  Created by Brandon Thomas on 6/28/26.
//

import Foundation
import Testing
@testable import SwiftBible

// for testing only; Swift warns about main-actor default isolation,
// why is this needed here?
@MainActor
struct YouVersionBibleIndexResponseTests {

    private var indexResponse: String = """
        {
            "text_direction": "ltr",
            "books": [
                {
                    "id": "GEN",
                    "title": "Genesis",
                    "full_title": "Genesis",
                    "abbreviation": "Genesis",
                    "canon": "old_testament",
                    "chapters": [
                        {
                            "id": "1",
                            "passage_id": "GEN.1",
                            "title": "1",
                            "verses": [
                                { "id": "1", "passage_id": "GEN.1.1", "title": "1" },
                                { "id": "2", "passage_id": "GEN.1.2", "title": "2" },
                                { "id": "3", "passage_id": "GEN.1.3", "title": "3" },
                                { "id": "4", "passage_id": "GEN.1.4", "title": "4" },
                                { "id": "5", "passage_id": "GEN.1.5", "title": "5" },
                                { "id": "6", "passage_id": "GEN.1.6", "title": "6" },
                                { "id": "7", "passage_id": "GEN.1.7", "title": "7" },
                                { "id": "9", "passage_id": "GEN.1.9", "title": "9" },
                                { "id": "10", "passage_id": "GEN.1.10", "title": "10" },
                                { "id": "11", "passage_id": "GEN.1.11", "title": "11" },
                                { "id": "12", "passage_id": "GEN.1.12", "title": "12" },
                                { "id": "13", "passage_id": "GEN.1.13", "title": "13" },
                                { "id": "14", "passage_id": "GEN.1.14", "title": "14" },
                                { "id": "16", "passage_id": "GEN.1.16", "title": "16" },
                                { "id": "17", "passage_id": "GEN.1.17", "title": "17" },
                                { "id": "18", "passage_id": "GEN.1.18", "title": "18" },
                                { "id": "19", "passage_id": "GEN.1.19", "title": "19" },
                                { "id": "20", "passage_id": "GEN.1.20", "title": "20" },
                                { "id": "21", "passage_id": "GEN.1.21", "title": "21" },
                                { "id": "22", "passage_id": "GEN.1.22", "title": "22" },
                                { "id": "23", "passage_id": "GEN.1.23", "title": "23" },
                                { "id": "24", "passage_id": "GEN.1.24", "title": "24" },
                                { "id": "25", "passage_id": "GEN.1.25", "title": "25" },
                                { "id": "26", "passage_id": "GEN.1.26", "title": "26" },
                                { "id": "27", "passage_id": "GEN.1.27", "title": "27" },
                                { "id": "28", "passage_id": "GEN.1.28", "title": "28" },
                                { "id": "29", "passage_id": "GEN.1.29", "title": "29" },
                                { "id": "30", "passage_id": "GEN.1.30", "title": "30" },
                                { "id": "31", "passage_id": "GEN.1.31", "title": "31" }
                            ]
                        }
                    ],
                    "intro": { "id": "INTRO", "passage_id": "GEN.INTRO", "title": "" }
                }
            ]
        }
        """

    /// Attempt to parse test JSON via YouVersionBibleIndexResponse mapping
    @Test func mapperFunctionsSucceed() async throws {
        guard let responseData: Data = indexResponse.data(using: .utf8) else {
            #expect(Bool(false), "Could not parse `indexResponse` as UTF-8 encoded data")
            return
        }

        do {
            let jsonDecoder: JSONDecoder = .init()
            let decoded: YouVersionBibleIndexResponse = try jsonDecoder.decode(YouVersionBibleIndexResponse.self,
                                                                               from: responseData)

            let books: [Book] = decoded.booksForApp()

            guard let firstBook = books.first else {
                #expect(Bool(false), "Could not parse first book")
                return
            }

            #expect(!books.isEmpty)
            #expect(firstBook.id == "GEN")

            guard let firstChapter = firstBook.chapters.first else {
                #expect(Bool(false), "Could not parse first book's first chapter")
                return
            }

            #expect(firstChapter.id == "GEN.1")
        } catch {
            #expect(Bool(false), "Failed to decode `indexResponse`: \(error.localizedDescription)")
        }
    }

}
