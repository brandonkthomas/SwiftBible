//
//  RenderedPassage.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 7/2/26.
//

nonisolated struct RenderedPassage {

    // MARK: Properties

    var paragraphs: [RenderedParagraph]
    var footnotes: [Footnote]
}

/// What type of passage run is this?
///
/// Equatable for unit testing
nonisolated enum RenderedPassageRun: Equatable {
    case text(String)
    case verseLabel(String)
    case footnoteMarker(Footnote.ID)
}
