//
//  SettingsAppearanceView.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 2026-11-13.
//

import SwiftUI

struct SettingsAppearanceView: View {

    // MARK: Properties

    /// Read appEnvironment.preferencesStore environment value from current view environment
    @Environment(PreferencesStore.self) private var preferencesStore: PreferencesStore

    // MARK: Views

    /// Main view
    var body: some View {
        VStack(spacing: 16) {
            // Preview
            PassagePreviewView(verses: Self.previewVerses,
                               readerTheme: preferencesStore.readerTheme)
//            .mask(
//                LinearGradient(gradient: Gradient(colors: [Color.black, Color.black, Color.black.opacity(0)]),
//                               startPoint: .center,
//                               endPoint: .bottom)
//            )
            // Settings
            ScrollView {
                themePresetsGridView
            }
        }
        .navigationTitle("Appearance")
    }

    /// Sample text for the theme preview window
    private static let previewVerses = [
        "In the beginning, God created the heavens and the earth.",
        "The earth was without form and void, and darkness was over the face of the deep. And the Spirit of God was hovering over the face of the waters.",
        "And God said, “Let there be light,” and there was light.",
    ]

    /// Grid of all theme presets (max 2 rows)
    private var themePresetsGridView: some View {
        let columnCount = (ReaderTheme.allCases.count + 1) / 2
        let columns = Array(repeating: GridItem(.flexible(), spacing: 10),
                            count: columnCount)

        return LazyVGrid(columns: columns, spacing: 10) {
            ForEach(ReaderTheme.allCases, id: \.self) { theme in
                Button {
                    preferencesStore.readerTheme = theme
                } label: {
                    VStack {
                        Text("Aa")
                            .dynamicTypeSize(.xxxLarge)
                        Text(theme.displayName)
                            .dynamicTypeSize(.large)
                    }
                    // font
                    .fontDesign(theme.fontDesign)
                    .fontWeight(theme.fontWeight)
                    // internal padding
                    .padding(5)
                    // fill the column widths
                    .frame(maxWidth: .infinity)
                    // checkmark overlay (must be BEFORE glassEffect & colors)
                    .overlay(alignment: .topTrailing) {
                        if preferencesStore.readerTheme == theme {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .medium))
                                .padding([.top, .trailing], 5)
                        }
                    }
                    // colors
                    .background(theme.backgroundColor)
                    .foregroundStyle(theme.primaryTextColor)
                    // size
                    .cornerRadius(10)
                    .glassEffect(.regular.interactive(),
                                 in: .rect(cornerRadius: 10))
                }
            }
        }
        .padding([.leading, .trailing], 1) // fix glass border clipping on edges
    }
}

#Preview {
    SettingsAppearanceView()
        .previewEnvironment(PreviewEnvironment(repository: FakeBibleRepository(throwWhenLoadingTranslations: true)))
}
