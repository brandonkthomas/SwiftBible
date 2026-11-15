//
//  PassageTextRendererTests.swift
//  SwiftBibleTests
//
//  Created by Brandon Thomas on 2026-11-15.
//

import Foundation
import SwiftUI
import Testing
@testable import SwiftBible

struct PassageTextRendererTests {

    // MARK: Character and Word Spacing

    /// Letters get the letter spacing; spaces get letter + word spacing, so neither one
    /// replaces the other
    @Test func spacesGetLetterPlusWordSpacing() {
        let text = "In the beginning, God"
        let spaced = PassageTextRenderer.spacedText(text, characterSpacing: 1.7, wordSpacing: 3.4)

        #expect(String(spaced.characters) == text)
        for run in spaced.runs {
            let runText = String(spaced[run.range].characters)
            if runText.allSatisfy({ $0 == " " }) {
                #expect(run.tracking == 5.1, "space run \"\(runText)\"")
            } else {
                #expect(run.tracking == 1.7, "word run \"\(runText)\"")
            }
        }
    }

    /// Word spacing alone widens only the spaces; repeated, leading and trailing spaces all count
    @Test func wordSpacingAloneWidensEverySpace() {
        let text = " a  b "
        let spaced = PassageTextRenderer.spacedText(text, characterSpacing: 0, wordSpacing: 2)
        let widenedSpaces = spaced.runs
            .filter { $0.tracking == 2 }
            .reduce(0) { $0 + spaced[$1.range].characters.count }

        #expect(String(spaced.characters) == text)
        #expect(widenedSpaces == 4)
        #expect(spaced.runs.allSatisfy { $0.tracking == 2 || $0.tracking == nil })
    }

    /// No spacing leaves the text without any tracking attribute
    @Test func zeroSpacingAddsNothing() {
        let spaced = PassageTextRenderer.spacedText("In the beginning", characterSpacing: 0, wordSpacing: 0)

        #expect(String(spaced.characters) == "In the beginning")
        #expect(spaced.runs.allSatisfy { $0.tracking == nil })
    }
}
