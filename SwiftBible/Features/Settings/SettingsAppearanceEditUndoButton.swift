//
//  SettingsAppearanceEditUndoButton.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 2026-11-15.
//

import SwiftUI

struct SettingsAppearanceEditUndoButton: View {

    let isEdited: Bool

    let action: () -> Void

    var body: some View {
        if isEdited {
            Button(action: action) {
                Label("Revert to Default", systemImage: "arrow.uturn.backward")
                    .labelStyle(.iconOnly)
            }
            // on the Button (not its label): without it, a List row sends every tap to its first button
            .buttonStyle(.borderless)
        }
    }
}
