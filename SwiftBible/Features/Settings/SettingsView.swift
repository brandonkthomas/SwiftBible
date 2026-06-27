//
//  SettingsView.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 6/27/26.
//

import SwiftUI

struct SettingsView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "Themes",
                systemImage: "paintbrush",
                description: Text("Coming soon.")
            )
            .navigationTitle("Themes")
            .navigationBarHidden(true)
        }
    }
}

#Preview {
    SettingsView()
}
