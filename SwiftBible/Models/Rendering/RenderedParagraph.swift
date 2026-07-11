//
//  RenderedParagraph.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 7/2/26.
//

import Foundation

nonisolated struct RenderedParagraph {

    // MARK: Properties

    var style: RenderedParagraphStyle = .paragraph
    var runs: [RenderedPassageRun]
}

/// Style to present the rendered paragraph in (para, line quote, indented quote)
nonisolated enum RenderedParagraphStyle: Equatable {
    case paragraph
    case quoteLine
    case indentedLine
}
