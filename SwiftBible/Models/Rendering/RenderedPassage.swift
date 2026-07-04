//
//  RenderedPassage.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 7/2/26.
//

nonisolated struct RenderedPassage {
    var paragraphs: [RenderedParagraph]
    var footnotes: [Footnote]
}

nonisolated enum RenderedPassageRun: Equatable {
    case text(String, verseRange: RenderedVerseRange?)
    case verseLabel(displayText: String, verseRange: RenderedVerseRange?)
    case footnoteMarker(Footnote.ID, verseRange: RenderedVerseRange?)
}

nonisolated struct RenderedVerseRange: Equatable {
    let startVerse: Int
    let endVerse: Int?

    init(startVerse: Int, endVerse: Int? = nil) {
        self.startVerse = startVerse
        self.endVerse = endVerse
    }
}
