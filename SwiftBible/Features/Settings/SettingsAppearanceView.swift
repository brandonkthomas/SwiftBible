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

    var body: some View {
        Grid(alignment: .center,
             horizontalSpacing: 10,
             verticalSpacing: 10) {
            ForEach(ReaderTheme.allCases, id: \.self) { theme in
                Button {

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
                    // external padding
                    .padding(5)
                    // min width
                    .frame(minWidth: 100)
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
    }
}

#Preview {
    SettingsAppearanceView()
        .previewEnvironment(PreviewEnvironment(repository: FakeBibleRepository(throwWhenLoadingTranslations: true)))
}
