//
//  SettingsReaderView.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 2026-11-16.
//

import SwiftUI

struct SettingsReaderView: View {

    ///
    @State private var readerSettingsListenModeEnabled: Bool = false

    ///
    var body: some View {
        List {
            Section {
                Toggle(isOn: $readerSettingsListenModeEnabled,
                       label: {
                    Text("Show Listen Mode")
                })
                .disabled(true)
            } header: {
                Text("Listen Mode")
            } footer: {
                Text("Coming soon.")
                    .font(.footnote)
            }
        }
    }
}

#Preview {
    SettingsReaderView()
}
