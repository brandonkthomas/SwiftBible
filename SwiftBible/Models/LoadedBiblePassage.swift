//
//  LoadedBiblePassage.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 2026-09-02.
//

import Foundation

/// The successful stored result of fetching + parsing a single passage
nonisolated struct LoadedBiblePassage {
    let passage: Passage
    let renderedPassage: RenderedPassage
}
