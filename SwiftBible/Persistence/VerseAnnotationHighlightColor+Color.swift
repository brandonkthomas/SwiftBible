//
//  VerseAnnotationHighlightColor+Color.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 2026-07-14.
//

import Foundation
import SwiftUI

extension VerseAnnotationHighlightColor {
    var color: Color {
        switch self {
        case .blue:
            return Color(.systemBlue)
        case .green:
            return Color(.systemGreen)
        case .pink:
            return Color(.systemPink)
        case .purple:
            return Color(.systemPurple)
        case .yellow:
            return Color(.systemYellow)
        }
    }
}
