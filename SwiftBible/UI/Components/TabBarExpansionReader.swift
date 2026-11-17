//
//  TabBarExpansionReader.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 2026-11-17.
//

import Foundation
import SwiftUI

/// Reports whether the tab bar is expanded. SwiftUI has no direct tab bar minimized state,
/// but the bottom accessory's placement is `.inline` exactly when the tab bar is minimized.
/// Must be placed inside `tabViewBottomAccessory` content to receive the placement.
struct TabBarExpansionReader: View {

    @Environment(\.tabViewBottomAccessoryPlacement) private var placement

    @Binding var isExpanded: Bool

    var body: some View {
        Color.clear
            .onChange(of: placement, initial: true) { _, newValue in
                isExpanded = newValue != .inline
            }
    }
}
