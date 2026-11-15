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

    // MARK: Presets / Customizations

    /// What's the preset used as this theme's base?
    var basePreset: ReaderTheme

    /// What customizations does this theme have? (`nil` = none)
    var customizedPreset: ReaderThemeCustom?

    /// Localized string display name; `*` marks a customized preset
    var displayName: LocalizedStringResource {
        "\(basePreset.displayName)\(customizedPreset?.isCustomized == true ? "*" : "")"
    }

    // MARK: Colors

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

    // MARK: Fonts

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

    // MARK: Scoped Fonts

    var scriptureFont: Font {
        self.font(.body, weight: fontWeight)
    }

    var divineNameFont: Font {
        self.font(.body, weight: self.emphasisWeight(minimum: .semibold))
    }

    var verseLabelFont: Font {
        self.font(.caption2)
    }

    var markerFont: Font {
        self.font(.caption2, weight: self.emphasisWeight(minimum: .bold))
    }

    // MARK: Functions

    /// Centralized font builder (for specific style/weight)
    func font(_ textStyle: Font.TextStyle,
              weight: ReaderThemeCustomFontWeight = .regular) -> Font {
        let nearestWeight = font.nearestWeight(to: weight,
                                               design: fontDesign.design)
        return font.font(textStyle,
                         design: fontDesign.design,
                         weight: nearestWeight.weight)
    }

    /// Centralized font builder (for specific size/weight)
    func font(fixedSize size: CGFloat,
              weight: ReaderThemeCustomFontWeight = .regular) -> Font {
        let nearestWeight = font.nearestWeight(to: weight,
                                               design: fontDesign.design)
        return font.font(fixedSize: size,
                         design: fontDesign.design,
                         weight: nearestWeight.weight)
    }

    /// Minimum weight calculator for emphasis text
    func emphasisWeight(minimum: ReaderThemeCustomFontWeight) -> ReaderThemeCustomFontWeight {
        let allWeights = ReaderThemeCustomFontWeight.allCases

        // sanity check: 0 is not possible since allWeights is every possible case
        let minIndex = allWeights.firstIndex(of: minimum) ?? 0
        let currentIndex = allWeights.firstIndex(of: fontWeight) ?? 0

        // two steps heavier than the body weight, capped at max
        let bumpedIndex = min(currentIndex + 2, allWeights.count - 1)
        let targetIndex = max(minIndex, bumpedIndex)

        // first available weight at or above the target, else the heaviest
        let available = availableFontWeights
        let match = available.first { (allWeights.firstIndex(of: $0) ?? 0) >= targetIndex }
        return match ?? available.last ?? allWeights[targetIndex]
    }

    /// Calculated baseline offset for the marker font, given a specific Dynamic Type Size
    func markerBaselineOffset(dynamicTypeSize: DynamicTypeSize) -> CGFloat {
        var environmentValues = EnvironmentValues()
        environmentValues.dynamicTypeSize = dynamicTypeSize

        let uiTraitCollection = UITraitCollection(
            preferredContentSizeCategory: UIContentSizeCategory(dynamicTypeSize)
        )

        let context = environmentValues.fontResolutionContext
        // resolve(in:) already applies Dynamic Type, so the ascents are not scaled again
        let bodyAscent = CTFontGetAscent(scriptureFont.resolve(in: context).ctFont)
        let labelAscent = CTFontGetAscent(verseLabelFont.resolve(in: context).ctFont)

        // Room between the label's top and the body text's top
        let room = bodyAscent - labelAscent
        let raise = UIFontMetrics(forTextStyle: .body).scaledValue(
            for: 6,
            compatibleWith: uiTraitCollection
        )
        return min(raise, room)
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
