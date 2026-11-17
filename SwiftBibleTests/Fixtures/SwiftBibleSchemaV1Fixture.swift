//
//  SwiftBibleSchemaV1Fixture.swift
//  SwiftBibleTests
//
//  Created by Brandon Thomas on 2026-11-16.
//

import Foundation
import SwiftData
@testable import SwiftBible

/// Writes a store the way V1-era builds did (frozen V1 classes, no migration plan) and returns
/// the app-facing values the repository must read back after any later migration.
///
/// Uses the nested `SwiftBibleSchemaV1.` names on purpose: once V2 exists, the plain
/// `StoredVerseAnnotation` means V2's class. Never change the rows below; add a new fixture per version.
@MainActor
enum SwiftBibleSchemaV1Fixture {

    static func seedStore(at url: URL) throws -> [VerseAnnotation] {
        let schema = Schema(versionedSchema: SwiftBibleSchemaV1.self)

        // no migration plan: V1-era builds wrote their stores without one
        let configuration = ModelConfiguration(schema: schema,
                                               url: url,
                                               cloudKitDatabase: .none)
        let modelContainer = try ModelContainer(for: schema,
                                                configurations: [configuration])
        let modelContext = ModelContext(modelContainer)

        var expected: [VerseAnnotation] = []

        /// Inserts one V1 row and records the value the repository should map it to.
        /// Whole-second dates so they compare equal after the store round trip.
        func add(translationID: Int,
                 bookCode: String,
                 chapter: Int,
                 startVerse: Int,
                 endVerse: Int? = nil,
                 content: AnnotationContent,
                 tags: [SwiftBibleSchemaV1.StoredTag] = [],
                 createdAt: TimeInterval,
                 updatedAt: TimeInterval? = nil) {
            let id = UUID()
            let createdDate = Date(timeIntervalSinceReferenceDate: createdAt)
            let updatedDate = updatedAt.map { Date(timeIntervalSinceReferenceDate: $0) }

            var highlightColor: VerseAnnotationHighlightColor?
            var note: String?
            if case .highlight(let color) = content { highlightColor = color }
            if case .note(let text) = content { note = text }

            let stored = SwiftBibleSchemaV1.StoredVerseAnnotation(id: id,
                                                                  translationID: translationID,
                                                                  bookCode: bookCode,
                                                                  chapter: chapter,
                                                                  startVerse: startVerse,
                                                                  endVerse: endVerse,
                                                                  highlightColor: highlightColor,
                                                                  note: note,
                                                                  createdAt: createdDate,
                                                                  updatedAt: updatedDate)
            modelContext.insert(stored)
            if !tags.isEmpty {
                stored.tags = tags
            }

            expected.append(VerseAnnotation(id: id,
                                            translationID: translationID,
                                            bookCode: bookCode,
                                            chapter: chapter,
                                            startVerse: startVerse,
                                            endVerse: endVerse,
                                            content: content,
                                            createdAt: createdDate,
                                            updatedAt: updatedDate))
        }

        // one highlight per color; purple is a range, green was edited later
        add(translationID: 111, bookCode: "JHN", chapter: 3, startVerse: 16,
            content: .highlight(.yellow), createdAt: 815_000_000)
        add(translationID: 59, bookCode: "PSA", chapter: 46, startVerse: 10,
            content: .highlight(.green), createdAt: 815_000_100, updatedAt: 815_086_400)
        add(translationID: 116, bookCode: "ISA", chapter: 40, startVerse: 31,
            content: .highlight(.blue), createdAt: 815_000_200)
        add(translationID: 1, bookCode: "GEN", chapter: 1, startVerse: 1,
            content: .highlight(.pink), createdAt: 815_000_300)
        add(translationID: 111, bookCode: "PSA", chapter: 23, startVerse: 1, endVerse: 3,
            content: .highlight(.purple), createdAt: 815_000_400)

        // note
        add(translationID: 111, bookCode: "ROM", chapter: 8, startVerse: 28,
            content: .note("Read this when things go wrong."), createdAt: 815_000_500)

        // tags: "Grace" is shared by both annotations; the second also has "Hope"
        let grace = SwiftBibleSchemaV1.StoredTag(id: UUID(), displayName: "Grace", normalizedName: "grace")
        let hope = SwiftBibleSchemaV1.StoredTag(id: UUID(), displayName: "Hope", normalizedName: "hope")
        add(translationID: 59, bookCode: "MAT", chapter: 5, startVerse: 9,
            content: .tags(["Grace"]), tags: [grace], createdAt: 815_000_600)
        add(translationID: 111, bookCode: "EPH", chapter: 2, startVerse: 8, endVerse: 9,
            content: .tags(["Grace", "Hope"]), tags: [grace, hope], createdAt: 815_000_700)

        try modelContext.save()

        return expected
    }
}
