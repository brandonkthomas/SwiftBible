//
//  SwiftBibleUITests.swift
//  SwiftBibleUITests
//

import XCTest

/// VoiceOver smoke tests for the Reader's controls
///
/// Run on an iOS 27 or later Simulator or device; `XCUIVoiceOverService` doesn't exist earlier.
/// Needs network access unless the opening passage is already cached.
///
/// These tests must stay read-only: a UI-tested app uses its real library and iCloud sync
/// (`AppEnvironment.isRunningTests` is only true for tests hosted inside the app process).
/// Never tap a highlight color or "Remove Highlight" here.
@available(iOS 27.0, *)
@MainActor
final class SwiftBibleVoiceOverUITests: XCTestCase {

    // MARK: Properties (Private)

    private var app: XCUIApplication!

    private var voiceOver: XCUIVoiceOverService {
        XCUIDevice.shared.voiceOverService
    }

    /// Upper limit per direction, so a long chapter can't keep a test running indefinitely
    private static let maxFocusMoves = 200

    /// The same speech this many times in a row means VoiceOver reached the end
    private static let maxRepeatedSpeech = 3

    // MARK: Setup

    override func setUp() async throws {
        continueAfterFailure = false

        app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.buttons["Next Chapter"].waitForExistence(timeout: 30),
                      "The Reader did not finish loading a passage")
    }

    override func tearDown() async throws {
        try? voiceOver.disable()
        app.terminate()
    }

    // MARK: Tests

    func testChapterButtonsAreAnnounced() throws {
        try voiceOver.enable()

        try assertVoiceOverAnnounces(["Previous Chapter", "Next Chapter"])
    }

    func testVerseActionsAreAnnounced() throws {
        try selectVerse()
        try voiceOver.enable()

        // "Highlight" also matches "Remove Highlight" when the verse is already highlighted
        try assertVoiceOverAnnounces(["Deselect Verses", "Highlight", "Notes and Tags", "Share"])
    }

    func testHighlightColorsAreAnnounced() throws {
        try selectVerse()

        // Exact label: on an already highlighted verse this button deletes the highlight
        let highlightButton = app.buttons["Highlight"]
        guard highlightButton.waitForExistence(timeout: 2) else {
            throw XCTSkip("The selected verse is already highlighted; this test won't remove it")
        }
        highlightButton.tap()

        XCTAssertTrue(app.buttons["Add Yellow Highlight"].waitForExistence(timeout: 5),
                      "The highlight color picker did not open")

        try voiceOver.enable()

        try assertVoiceOverAnnounces(["Add Yellow Highlight",
                                      "Add Green Highlight",
                                      "Add Blue Highlight",
                                      "Add Pink Highlight",
                                      "Add Purple Highlight"])
    }

    // MARK: Functions (Private)

    /// Taps down the middle of the passage until a verse is selected
    private func selectVerse() throws {
        let deselectButton = app.buttons["Deselect Verses"]
        let passage = app.scrollViews.firstMatch
        XCTAssertTrue(passage.waitForExistence(timeout: 5), "The passage is not visible")

        for verticalOffset in stride(from: 0.2, through: 0.6, by: 0.1) {
            passage.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: verticalOffset)).tap()

            if deselectButton.waitForExistence(timeout: 2) {
                return
            }
        }

        XCTFail("Tapping the passage did not select a verse")
    }

    /// Moves VoiceOver forward, then backward, until every expected phrase has been spoken
    private func assertVoiceOverAnnounces(_ expectedPhrases: [String],
                                          file: StaticString = #filePath,
                                          line: UInt = #line) throws {
        var missingPhrases = expectedPhrases
        var transcript: [String] = []

        func record(_ utterance: String) {
            transcript.append(utterance)
            missingPhrases.removeAll { utterance.localizedCaseInsensitiveContains($0) }
        }

        if let current = try? voiceOver.currentSpeech() {
            record(current.utterance)
        }

        walkFocus(move: { try self.voiceOver.moveForward().utterance },
                  record: record,
                  isFinished: { missingPhrases.isEmpty })
        walkFocus(move: { try self.voiceOver.moveBackward().utterance },
                  record: record,
                  isFinished: { missingPhrases.isEmpty })

        let attachment = XCTAttachment(string: transcript.joined(separator: "\n"))
        attachment.name = "VoiceOver transcript"
        attachment.lifetime = .keepAlways
        add(attachment)

        XCTAssertTrue(missingPhrases.isEmpty,
                      "VoiceOver never announced: \(missingPhrases.joined(separator: ", "))",
                      file: file,
                      line: line)
    }

    /// Moves focus in one direction until finished, out of elements, or out of attempts
    private func walkFocus(move: () throws -> String,
                           record: (String) -> Void,
                           isFinished: () -> Bool) {
        var previousUtterance: String?
        var repeatCount = 0

        for _ in 0..<Self.maxFocusMoves where !isFinished() {
            guard let utterance = try? move() else { return }

            record(utterance)

            repeatCount = utterance == previousUtterance ? repeatCount + 1 : 0
            previousUtterance = utterance

            if repeatCount >= Self.maxRepeatedSpeech {
                return
            }
        }
    }
}
