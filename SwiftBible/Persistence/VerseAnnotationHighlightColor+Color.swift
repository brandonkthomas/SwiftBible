//
//  VerseAnnotationHighlightColor+Color.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 2026-07-14.
//

import Foundation
import SwiftUI

extension VerseAnnotationHighlightColor {
    var uiColor: Color {
        switch self {
        case .blue:
            return Color(.verseAnnotationHighlightColorBlue)
        case .green:
            return Color(.verseAnnotationHighlightColorGreen)
        case .pink:
            return Color(.verseAnnotationHighlightColorPink)
        case .purple:
            return Color(.verseAnnotationHighlightColorPurple)
        case .yellow:
            return Color(.verseAnnotationHighlightColorYellow)
        }
    }
}
