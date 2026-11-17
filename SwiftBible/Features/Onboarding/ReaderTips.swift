//
//  ReaderTips.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 2026-11-17.
//

import Foundation
import TipKit

struct PassagePickerTip: Tip {
    var title: Text {
        Text("Choose a Passage")
    }

    var message: Text? {
        Text("Tap here to pick a translation, book, and chapter.")
    }

    var image: Image? {
        Image(systemName: "books.vertical")
    }
}
