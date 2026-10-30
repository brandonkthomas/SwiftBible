//
//  VerseLabelAttribute.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 2026-10-29.
//

import SwiftUI

/// Must be unique from (the otherwise identical) VerseNumberAttribute
/// because VerseNumberAttribute is used to build highlight rectangles
struct VerseLabelAttribute: TextAttribute {
    let number: Int
}
