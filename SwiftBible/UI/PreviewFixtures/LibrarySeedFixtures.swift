//
//  LibrarySeedFixtures.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 2026-11-20.
//

#if DEBUG
import Foundation

/// Library contents for the DEBUG-only `-seedLibrary` launch argument (see `AppEnvironment`).
///
/// Copied from a simulator's `default.store` on 2026-11-20 (17 annotations): IDs, references,
/// content, and `createdAt` match the store; `createdAt` values are seconds since 2001-01-01
/// (Core Data's timestamp format).
enum LibrarySeedFixtures {

    static let annotations: [VerseAnnotation] = [
        seed("288D8539-5400-4967-9BCE-28D4A860DA98", translationID: 111, bookCode: "PSA", chapter: 23,
             startVerse: 1, endVerse: 3,
             content: .highlight(.green),
             createdAt: 816616800),
        seed("242DB32D-CCD0-4714-8D5C-E66F0592D621", translationID: 59, bookCode: "ROM", chapter: 8,
             startVerse: 38, endVerse: 39,
             content: .note("Nothing in all creation can separate us from his love. Come back to this on the hard days."),
             createdAt: 816436800),
        seed("B068AD64-D97D-49E0-A699-BC7E54927D2D", translationID: 116, bookCode: "PRO", chapter: 3,
             startVerse: 5, endVerse: 6,
             content: .tags(["Trust", "Wisdom", "Guidance"]),
             createdAt: 816274800),
        seed("A7828E82-70C0-4043-9538-AF74AE715C2F", translationID: 111, bookCode: "ISA", chapter: 40,
             startVerse: 31, endVerse: nil,
             content: .highlight(.blue),
             createdAt: 816094800),
        seed("C0366118-2D54-492C-8C75-49B11A2BFA37", translationID: 59, bookCode: "PHP", chapter: 4,
             startVerse: 6, endVerse: 7,
             content: .note("Pray first. Peace follows."),
             createdAt: 815914800),
        seed("BE1F1823-E2CE-4F0C-B9A5-7FAF15088857", translationID: 116, bookCode: "MAT", chapter: 11,
             startVerse: 28, endVerse: 30,
             content: .tags(["Rest", "Comfort"]),
             createdAt: 815752800),
        seed("E52B214C-7B40-4079-A09B-2BAF9B907045", translationID: 59, bookCode: "LAM", chapter: 3,
             startVerse: 22, endVerse: 23,
             content: .highlight(.pink),
             createdAt: 815572800),
        seed("69CEBAC6-F10A-4000-9E48-B35DA3A41077", translationID: 111, bookCode: "HEB", chapter: 11,
             startVerse: 1, endVerse: nil,
             content: .note("Faith looks forward with confidence."),
             createdAt: 815410800),
        seed("360AFAC8-345B-496A-BBC5-26EB01E9FF9B", translationID: 116, bookCode: "JAS", chapter: 1,
             startVerse: 5, endVerse: nil,
             content: .highlight(.purple),
             createdAt: 815230800),
        seed("7346A611-229D-4661-9D02-2FAAC21B04F4", translationID: 111, bookCode: "1CO", chapter: 13,
             startVerse: 4, endVerse: 7,
             content: .tags(["Love", "Memorize"]),
             createdAt: 815050800),
        seed("E27C4BD1-CE19-499C-8922-1C1CBC700526", translationID: 59, bookCode: "EPH", chapter: 2,
             startVerse: 8, endVerse: 9,
             content: .highlight(.yellow),
             createdAt: 814888800),
        seed("9F93724A-7717-48EF-A913-B64D06275BFC", translationID: 116, bookCode: "JOS", chapter: 1,
             startVerse: 9, endVerse: nil,
             content: .note("Read this before the move."),
             createdAt: 814708800),
        seed("C37AE1E5-F7B9-4128-9B06-3648DC9F5B8B", translationID: 111, bookCode: "JHN", chapter: 15,
             startVerse: 5, endVerse: nil,
             content: .note("Fruit comes from staying close to him, not from trying harder."),
             createdAt: 814546800),
        seed("C5EF6787-B0DB-4400-B615-F1AD82E8150C", translationID: 111, bookCode: "JHN", chapter: 15,
             startVerse: 5, endVerse: nil,
             content: .tags(["Memorize", "Abide", "Discipleship"]),
             createdAt: 814366800),
        seed("C6777EB8-9046-4AA8-BF44-D39184899B06", translationID: 111, bookCode: "JHN", chapter: 1,
             startVerse: 5, endVerse: nil,
             content: .highlight(.yellow),
             createdAt: 814186800),
        seed("493CF373-C497-4800-BDB3-F078E683B0D3", translationID: 111, bookCode: "JHN", chapter: 1,
             startVerse: 5, endVerse: nil,
             content: .note("Test"),
             createdAt: 816754353.190606),
        seed("68368C76-24FD-4F5C-B9F2-C9EEEABF0446", translationID: 111, bookCode: "JHN", chapter: 1,
             startVerse: 5, endVerse: nil,
             content: .tags(["Abide"]),
             createdAt: 816754353.19218099),
    ]

    private static func seed(_ id: String,
                             translationID: Int,
                             bookCode: String,
                             chapter: Int,
                             startVerse: Int,
                             endVerse: Int?,
                             content: AnnotationContent,
                             createdAt: TimeInterval) -> VerseAnnotation {
        VerseAnnotation(id: UUID(uuidString: id)!,
                        translationID: translationID,
                        bookCode: bookCode,
                        chapter: chapter,
                        startVerse: startVerse,
                        endVerse: endVerse,
                        content: content,
                        createdAt: Date(timeIntervalSinceReferenceDate: createdAt))
    }
}
#endif
