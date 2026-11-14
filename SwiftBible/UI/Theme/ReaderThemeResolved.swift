//
//  ReaderThemeResolved.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 2026-11-13.
//

import SwiftUI

/// ReaderTheme (base) with applied + computed customizations (ReaderThemeCustom)
///
/// Built by `PreferencesStore`; never saved.
struct ReaderThemeResolved: Equatable {

    /// What's the preset used as this theme's base?
    var basePreset: ReaderTheme

    /// What customizations does this theme have? (`nil` = none)
    var customizedPreset: ReaderThemeCustom?

    /// Localized string display name; `*` marks a customized preset
    var displayName: LocalizedStringResource {
        "\(basePreset.displayName)\(customizedPreset?.isCustomized == true ? "*" : "")"
    }

    var backgroundColor: Color {
        Self.adaptiveColor(
            presetColor: basePreset.backgroundColor,
            light: customizedPreset?.backgroundColorLight,
            dark: customizedPreset?.backgroundColorDark
        )
    }

    var primaryTextColor: Color {
        Self.adaptiveColor(
            presetColor: basePreset.primaryTextColor,
            light: customizedPreset?.primaryTextColorLight,
            dark: customizedPreset?.primaryTextColorDark
        )
    }

    var secondaryTextColor: Color {
        Self.adaptiveColor(
            presetColor: basePreset.secondaryTextColor,
            light: customizedPreset?.secondaryTextColorLight,
            dark: customizedPreset?.secondaryTextColorDark
        )
    }

    /// Custom font (base preset if not customized)
    var font: ReaderThemeFont {
        customizedPreset?.font ?? basePreset.font
    }

    /// Custom font design (base preset if not customized)
    var fontDesign: ReaderThemeCustomFontDesign {
        customizedPreset?.fontDesign ?? basePreset.fontDesign
    }

    /// edit's weight (else the preset's) snapped to nearest supported weight
    var fontWeight: ReaderThemeCustomFontWeight {
        let requestedWeight = customizedPreset?.fontWeight ?? basePreset.fontWeight
        return font.nearestWeight(to: requestedWeight, design: fontDesign.design)
    }

    /// All available font weights for this resolved font choice
    var availableFontWeights: [ReaderThemeCustomFontWeight] {
        font.availableWeights(design: fontDesign.design)
    }

    /// One color that picks the light or dark value when it is drawn.
    ///
    /// UIKit calls the provider closure with the trait collection of whatever
    /// is drawing the color; `.preferredColorScheme` sets its
    /// `userInterfaceStyle`
    nonisolated private static func adaptiveColor(
        presetColor: Color,
        light: Color.Resolved?,
        dark: Color.Resolved?
    ) -> Color {
        // No edits: keep the asset color as-is.
        if light == nil && dark == nil {
            return presetColor
        }

        return Color(uiColor: UIColor { traits in
            let isDark = traits.userInterfaceStyle == .dark

            var environment = EnvironmentValues()
            environment.colorScheme = isDark ? .dark : .light

            let resolved = (isDark ? dark : light) ?? presetColor.resolve(in: environment)
            return UIColor(Color(resolved))
        })
    }
}
