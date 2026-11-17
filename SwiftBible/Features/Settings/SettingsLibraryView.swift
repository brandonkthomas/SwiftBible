//
//  SettingsLibraryView.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 2026-11-16.
//

import SwiftUI

struct SettingsLibraryView: View {

    ///
    @State private var librarySettingsSavedToCloudKit: Bool = false

    ///
    var body: some View {
        List {
            // Sync to iCloud
            Section {
                Toggle(isOn: $librarySettingsSavedToCloudKit,
                       label: {
                    Text("Sync to iCloud")
                })
                .disabled(true)
            } header: {
                Text("Backup")
            } footer: {
                Text(librarySettingsSavedToCloudKit ? "Annotations are backed up and available across your devices." : "Annotations are not backed up and are available only on this device.")
                    .font(.footnote)
            }
        }
        .navigationTitle("Annotations")
    }
}

#Preview {
    SettingsReaderView()
}
