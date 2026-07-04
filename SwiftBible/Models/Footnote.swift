//
//  Footnote.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 7/3/26.
//

nonisolated struct Footnote: Identifiable {
    let id: Int
    /// Used by ReaderPassageFootnoteSheetView
    let verseRange: RenderedVerseRange
    let text: String
}
