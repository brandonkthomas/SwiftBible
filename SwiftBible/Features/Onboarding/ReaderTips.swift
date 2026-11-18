//
//  ReaderTips.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 2026-11-17.
//

import Foundation
import TipKit

enum ReaderTips {
    static let onboarding = TipGroup(.ordered) {
        PassagePickerTip()
        VerseSelectionTip()
        VerseActionsTip()
        EdgeSwipeTip()
    }
}

// Tip 1: Passage Picker
struct PassagePickerTip: Tip {
    var title: Text {
        Text("Choose a Passage")
    }

    var message: Text? {
        Text("Tap the passage name below to pick a translation, book, and chapter.")
    }

    var image: Image? {
        Image(systemName: "books.vertical")
    }
}

// Tip 2: Select Verses
struct VerseSelectionTip: Tip {
    var title: Text {
        Text("Select Verses")
    }

    var message: Text? {
        Text("Tap a verse to select it. Tap another verse to select everything between.")
    }

    var image: Image? {
        Image(systemName: "hand.tap")
    }
}

// Tip 3: Selected Verse Actions
struct VerseActionsTip: Tip {
    var title: Text {
        Text("Annotate Verses")
    }

    var message: Text? {
        Text("Choose an action to annotate the selected verse(s).")
    }

    var image: Image? {
        Image(systemName: "bookmark")
    }
}

// Tip 4: Edge Swipe
struct EdgeSwipeTip: Tip {
    var title: Text {
        Text("Previous/Next Chapter")
    }

    var message: Text? {
        Text("Swipe from either edge of the screen to quickly change chapters.")
    }

    var image: Image? {
        Image(systemName: "hand.draw")
    }
}
