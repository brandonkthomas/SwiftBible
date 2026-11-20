//
//  ReaderThemeTests.swift
//  SwiftBibleTests
//
//  Created by Brandon Thomas on 2026-11-12.
//

import CoreText
import Foundation
import SwiftUI
import Testing
@testable import SwiftBible

struct ReaderThemeTests {

    /// No two presets share an ID; IDs are persisted, so a collision would load the wrong theme
    @Test func presetIDsAreUnique() {
        let ids = ReaderTheme.allCases.map(\.id)

        #expect(Set(ids).count == ids.count)
    }

    /// Looking up the default preset's ID returns the default preset
    @Test func lookupByDefaultIDReturnsDefault() {
        let found = ReaderTheme.preset(withID: ReaderTheme.default.id)

        #expect(found == ReaderTheme.default)
    }

    /// The default preset is one of the built-in presets
    @Test func defaultIsInPresetList() {
        #expect(ReaderTheme.allCases.contains(ReaderTheme.default))
    }

    /// Views outside the root's injection (previews, isolated subtrees) get the
    /// default preset with no customizations
    @MainActor
    @Test func environmentDefaultIsUncustomizedDefaultPreset() {
        let readerTheme: ReaderThemeResolved = EnvironmentValues().readerTheme

        #expect(readerTheme.basePreset == ReaderTheme.default)
        #expect(readerTheme.customizedPreset == nil)
    }

    // MARK: Adaptive Colors

    /// A preset with no color edits hands back the asset color itself
    @MainActor
    @Test func uncustomizedColorIsPresetColor() {
        let themeResolved = ReaderThemeResolved(basePreset: .ink)

        #expect(themeResolved.backgroundColor == ReaderTheme.ink.backgroundColor)
    }

    /// One custom color shows its light value in light mode and its dark value in dark mode
    @MainActor
    @Test func customBackgroundResolvesPerColorScheme() {
        let light = Color.Resolved(red: 0.9, green: 0.8, blue: 0.7)
        let dark = Color.Resolved(red: 0.1, green: 0.2, blue: 0.3)
        let themeResolved = ReaderThemeResolved(
            basePreset: .ink,
            customizedPreset: ReaderThemeCustom(backgroundColorLight: light, backgroundColorDark: dark)
        )

        #expect(isClose(themeResolved.backgroundColor.resolve(in: environment(.light)), light))
        #expect(isClose(themeResolved.backgroundColor.resolve(in: environment(.dark)), dark))
    }

    /// A mode with no custom value falls back to the preset's color for that mode
    @MainActor
    @Test func missingModeFallsBackToPresetColor() {
        let dark = Color.Resolved(red: 0.1, green: 0.2, blue: 0.3)
        let themeResolved = ReaderThemeResolved(
            basePreset: .ink,
            customizedPreset: ReaderThemeCustom(backgroundColorDark: dark)
        )
        let presetLight = ReaderTheme.ink.backgroundColor.resolve(in: environment(.light))

        #expect(isClose(themeResolved.backgroundColor.resolve(in: environment(.light)), presetLight))
        #expect(isClose(themeResolved.backgroundColor.resolve(in: environment(.dark)), dark))
    }

    /// The same color edits give equal colors on every read. A new, unequal color per read made
    /// SwiftUI treat every Reader paragraph as changed, which broke the verse selection animation
    @MainActor
    @Test func customColorsAreEqualAcrossReads() {
        let light = Color.Resolved(red: 0.9, green: 0.8, blue: 0.7)
        let dark = Color.Resolved(red: 0.1, green: 0.2, blue: 0.3)
        let edits = ReaderThemeCustom(backgroundColorLight: light,
                                      primaryTextColorDark: dark,
                                      secondaryTextColorLight: light)
        let first = ReaderThemeResolved(basePreset: .ink, customizedPreset: edits)
        let second = ReaderThemeResolved(basePreset: .ink, customizedPreset: edits)

        #expect(first.backgroundColor == second.backgroundColor)
        #expect(first.primaryTextColor == second.primaryTextColor)
        #expect(first.secondaryTextColor == second.secondaryTextColor)

        // different edits, or the same edits on another preset, still give a different color
        let otherEdits = ReaderThemeResolved(basePreset: .ink,
                                             customizedPreset: ReaderThemeCustom(backgroundColorLight: dark))
        let otherPreset = ReaderThemeResolved(basePreset: .linen, customizedPreset: edits)
        #expect(first.backgroundColor != otherEdits.backgroundColor)
        #expect(first.backgroundColor != otherPreset.backgroundColor)
    }

    // MARK: Fonts

    /// Every named font is installed; a missing family would quietly fall back to the system font
    @Test func namedFontsAreInstalled() {
        for font in ReaderThemeFont.allCases {
            guard let familyName = font.familyName else { continue }

            #expect(!UIFont.fontNames(forFamilyName: familyName).isEmpty,
                    "\(familyName) is not installed")
        }
    }

    /// The system font has no family name; its look comes from the Style (design) choice
    @Test func systemFontHasNoFamilyName() {
        #expect(ReaderThemeFont.system.familyName == nil)
    }

    /// A named font draws in its own family for any Style; a weight picks the family's
    /// matching face, and italic (emphasized Scripture text) picks its italic face
    @Test func namedFontResolvesToItsFamily() {
        for font in ReaderThemeFont.allCases {
            guard let familyName = font.familyName else { continue }
            let regular = resolve(font.font(.body, design: .default, weight: .regular))
            let boldSerif = resolve(font.font(.body, design: .serif, weight: .bold))
            let italic = resolve(font.font(.body, design: .default, weight: .regular).italic())

            #expect(CTFontCopyFamilyName(regular.ctFont) as String == familyName)
            #expect(CTFontCopyFamilyName(boldSerif.ctFont) as String == familyName)
            #expect(boldSerif.isBold, "\(familyName) bold did not pick a bold face")
            #expect(italic.isItalic, "\(familyName) italic did not pick an italic face")
        }
    }

    /// The system font builds the same font as `Font.system` with the given design,
    /// both for a text style and for a fixed size
    @Test(arguments: [Font.Design.default, .serif])
    func systemFontUsesGivenDesign(design: Font.Design) {
        #expect(resolve(ReaderThemeFont.system.font(.body, design: design, weight: .medium))
                == resolve(.system(.body, design: design, weight: .medium)))
        #expect(resolve(ReaderThemeFont.system.font(fixedSize: 14, design: design, weight: .medium))
                == resolve(.system(size: 14, weight: .medium, design: design)))
    }

    /// At the default Dynamic Type size, a named font has the system size for its text style
    @Test(arguments: [Font.TextStyle.body, .footnote, .caption, .caption2])
    func namedFontMatchesSystemSize(textStyle: Font.TextStyle) {
        let named = resolve(ReaderThemeFont.iowan.font(textStyle, design: .default, weight: .regular))
        let system = resolve(.system(textStyle))

        #expect(named.pointSize == system.pointSize)
    }

    /// At every Dynamic Type size a named font keeps caption2 < footnote < body, so verse
    /// labels and footnote markers stay smaller than the text around them
    @Test(arguments: DynamicTypeSize.allCases)
    func namedFontKeepsTextStyleOrder(dynamicTypeSize: DynamicTypeSize) {
        let font = ReaderThemeFont.iowan
        let body = resolve(font.font(.body, design: .default, weight: .regular), dynamicTypeSize)
        let footnote = resolve(font.font(.footnote, design: .default, weight: .regular), dynamicTypeSize)
        let caption2 = resolve(font.font(.caption2, design: .default, weight: .regular), dynamicTypeSize)

        #expect(caption2.pointSize < footnote.pointSize)
        #expect(footnote.pointSize < body.pointSize)
    }

    /// A fixed size was already scaled by the caller's `@ScaledMetric`, so the font must not scale it again
    @Test func fixedSizeFontIgnoresDynamicType() {
        for font in ReaderThemeFont.allCases {
            let resolved = resolve(font.font(fixedSize: 14, design: .default, weight: .regular), .accessibility3)

            #expect(resolved.pointSize == 14, "\(font) scaled a fixed size")
        }
    }

    // MARK: Font Weights

    /// Each listed weight draws a different face, and the list runs light to heavy
    @Test(arguments: [Font.Design.default, .serif])
    func availableWeightsDrawDistinctFaces(design: Font.Design) {
        for font in ReaderThemeFont.allCases {
            let weights = font.availableWeights(design: design)
            let faces = weights.map { faceName(font, design, $0.weight) }
            let positions = weights.compactMap { ReaderThemeCustomFontWeight.allCases.firstIndex(of: $0) }

            #expect(Set(faces).count == faces.count, "\(font) \(design) lists two weights with the same face")
            #expect(positions == positions.sorted(), "\(font) \(design) weights are not light to heavy")
        }
    }

    /// Every weight draws the same face as some listed weight, so no face is missing from the list
    @Test(arguments: [Font.Design.default, .serif])
    func everyWeightDrawsAListedFace(design: Font.Design) {
        for font in ReaderThemeFont.allCases {
            let listedFaces = Set(font.availableWeights(design: design).map { faceName(font, design, $0.weight) })

            for weight in ReaderThemeCustomFontWeight.allCases {
                #expect(listedFaces.contains(faceName(font, design, weight.weight)),
                        "\(font) \(design) \(weight) draws a face that is not listed")
            }
        }
    }

    /// A weight snaps to the nearest listed weight by position; a tie goes to the lighter one
    @Test func nearestWeightSnapsToListedWeight() {
        // .medium on a Regular/Bold family: Regular (1 step) beats Bold (2 steps)
        #expect(ReaderThemeFont.georgia.nearestWeight(to: .medium, design: .default) == .regular)
        #expect(ReaderThemeFont.georgia.nearestWeight(to: .semibold, design: .default) == .bold)
        // New York has no light weights
        #expect(ReaderThemeFont.system.nearestWeight(to: .light, design: .serif) == .regular)
        // San Francisco has every weight
        #expect(ReaderThemeFont.system.nearestWeight(to: .thin, design: .default) == .thin)
        // Seravek .thin sits between .ultraLight and .light: tie goes lighter
        #expect(ReaderThemeFont.seravek.nearestWeight(to: .thin, design: .default) == .ultraLight)
    }

    // MARK: Font and Style Edits

    /// With no edits, every preset resolves to its own font and Style
    @MainActor
    @Test func uncustomizedFontIsPresetFont() {
        for preset in ReaderTheme.allCases {
            let themeResolved = ReaderThemeResolved(basePreset: preset)

            #expect(themeResolved.font == preset.font)
            #expect(themeResolved.fontDesign == preset.fontDesign)
        }
    }

    /// A Font edit and a Style edit each replace only their own preset value
    @MainActor
    @Test func fontAndStyleEditsReplacePresetValues() {
        // Folio's Style is .serif; a Font edit alone keeps it
        let folio = ReaderThemeResolved(basePreset: .folio,
                                        customizedPreset: ReaderThemeCustom(font: .georgia))
        // Quiet's Style is .default; a Style edit alone keeps the system font
        let quiet = ReaderThemeResolved(basePreset: .quiet,
                                        customizedPreset: ReaderThemeCustom(fontDesign: .serif))

        #expect(folio.font == .georgia)
        #expect(folio.fontDesign == .serif)
        #expect(quiet.font == .system)
        #expect(quiet.fontDesign == .serif)
    }

    /// Font and Style edits survive a JSON round trip, and edits saved before these fields existed still load
    @Test func fontEditsDecodeAndOldDataStillLoads() throws {
        var edits = ReaderThemeCustom()
        edits.font = .charter
        edits.fontDesign = .serif
        let decoded = try JSONDecoder().decode(ReaderThemeCustom.self, from: JSONEncoder().encode(edits))

        // saved by the 5a build: weight only, no font or Style keys
        let savedBefore5b = Data(#"{"fontWeight":"bold"}"#.utf8)
        let old = try JSONDecoder().decode(ReaderThemeCustom.self, from: savedBefore5b)

        #expect(decoded == edits)
        #expect(old.fontWeight == .bold)
        #expect(old.font == nil)
        #expect(old.fontDesign == nil)
    }

    // MARK: Picker Labels and Style Row

    /// Weight menu labels, lightest first (the menu lists weights in `allCases` order)
    @Test func fontWeightDisplayNames() {
        let names = ReaderThemeCustomFontWeight.allCases.map { String(localized: $0.displayName) }

        #expect(names == ["Ultralight", "Thin", "Light", "Regular", "Medium",
                          "Semibold", "Bold", "Heavy", "Black"])
    }

    /// Style labels say what the reader sees; "Default" would not say sans serif
    @Test func fontDesignDisplayNames() {
        #expect(String(localized: ReaderThemeCustomFontDesign.default.displayName) == "Sans Serif")
        #expect(String(localized: ReaderThemeCustomFontDesign.serif.displayName) == "Serif")
    }

    /// The Style row is enabled only for the system font, because named fonts ignore Style
    @MainActor
    @Test(arguments: ReaderThemeFont.allCases)
    func styleIsEditableOnlyForSystemFont(font: ReaderThemeFont) {
        let themeResolved = ReaderThemeResolved(basePreset: .folio,
                                                customizedPreset: ReaderThemeCustom(font: font))

        #expect(themeResolved.canChangeFontDesign == (font == .system))
    }

    // MARK: Edits Decoding

    /// A value this build does not know (e.g. a font added by a newer build) drops only
    /// that field; the other edits in the same value still load
    @Test func unknownFontDropsOnlyThatField() throws {
        let savedByNewerBuild = Data(#"{"font":"futureFont","fontWeight":"bold","fontDesign":"serif"}"#.utf8)
        let edits = try JSONDecoder().decode(ReaderThemeCustom.self, from: savedByNewerBuild)

        #expect(edits.font == nil)
        #expect(edits.fontWeight == .bold)
        #expect(edits.fontDesign == .serif)
    }

    /// Every field survives a JSON round trip, so a field forgotten in `init(from:)` fails here
    /// (components 0, 0.5 and 1 encode exactly, so `==` works)
    @Test func everyFieldSurvivesRoundTrip() throws {
        let light = Color.Resolved(red: 1, green: 0.5, blue: 0)
        let dark = Color.Resolved(red: 0, green: 0.5, blue: 1)
        let edits = ReaderThemeCustom(backgroundColorLight: light,
                                      backgroundColorDark: dark,
                                      primaryTextColorLight: light,
                                      primaryTextColorDark: dark,
                                      secondaryTextColorLight: light,
                                      secondaryTextColorDark: dark,
                                      fontWeight: .semibold,
                                      font: .charter,
                                      fontDesign: .serif,
                                      lineSpacingPercent: 160,
                                      marginPoints: 36,
                                      characterSpacingPercent: 5,
                                      wordSpacingPercent: 10)

        let decoded = try JSONDecoder().decode(ReaderThemeCustom.self, from: JSONEncoder().encode(edits))

        #expect(decoded == edits)
    }

    // MARK: Resolved Fonts

    /// The theme builds its fonts from its own font and design: Classic with no edits is
    /// New York (system serif), Folio is Seravek, and a Georgia edit draws Georgia, for text
    /// styles and fixed sizes
    @MainActor
    @Test func themeFontUsesResolvedFontAndDesign() {
        let classic = ReaderThemeResolved(basePreset: .classic)
        let folio = ReaderThemeResolved(basePreset: .folio)
        let classicGeorgia = ReaderThemeResolved(basePreset: .classic,
                                                 customizedPreset: ReaderThemeCustom(font: .georgia))

        #expect(resolve(classic.font(.body)) == resolve(.system(.body, design: .serif, weight: .regular)))
        #expect(resolve(classic.font(fixedSize: 14)) == resolve(.system(size: 14, weight: .regular, design: .serif)))
        #expect(familyName(folio.font(.body)) == "Seravek")
        #expect(familyName(classicGeorgia.font(.body)) == "Georgia")
        #expect(familyName(classicGeorgia.font(fixedSize: 14)) == "Georgia")
    }

    /// A requested weight is snapped before drawing: .medium on Georgia draws Regular
    /// (CoreText alone would pick Bold), and .medium on the system font stays Medium
    @MainActor
    @Test func themeFontSnapsRequestedWeight() {
        let quiet = ReaderThemeResolved(basePreset: .quiet)
        let quietGeorgia = ReaderThemeResolved(basePreset: .quiet,
                                               customizedPreset: ReaderThemeCustom(font: .georgia))

        #expect(!resolve(quietGeorgia.font(.body, weight: .medium)).isBold)
        #expect(!resolve(quietGeorgia.font(fixedSize: 14, weight: .medium)).isBold)
        #expect(resolve(quiet.font(.body, weight: .medium)) == resolve(.system(.body, weight: .medium)))
    }

    /// With no weight given, the theme font is Regular; it does not take the theme's
    /// Scripture weight (Ink's .bold), because these fonts are for app chrome
    @MainActor
    @Test func themeFontDefaultsToRegularWeight() {
        let ink = ReaderThemeResolved(basePreset: .ink)

        #expect(resolve(ink.font(.body)) == resolve(ink.font(.body, weight: .regular)))
        #expect(resolve(ink.font(fixedSize: 14)) == resolve(ink.font(fixedSize: 14, weight: .regular)))
    }

    // MARK: Scripture Fonts

    /// With a regular body (Classic, New York), the Scripture fonts are body regular, divine name
    /// semibold, verse labels caption2 regular, markers caption2 bold
    @MainActor
    @Test func scriptureFontsMatchTodayForRegularBody() {
        let classic = ReaderThemeResolved(basePreset: .classic)

        #expect(resolve(classic.scriptureFont) == resolve(.system(.body, design: .serif, weight: .regular)))
        #expect(resolve(classic.divineNameFont) == resolve(.system(.body, design: .serif, weight: .semibold)))
        #expect(resolve(classic.verseLabelFont) == resolve(.system(.caption2, design: .serif, weight: .regular)))
        #expect(resolve(classic.markerFont) == resolve(.system(.caption2, design: .serif, weight: .bold)))
    }

    /// Emphasis is the minimum or two steps above the body weight, whichever is heavier,
    /// capped at the heaviest weight the font has
    @MainActor
    @Test func emphasisStaysAboveBodyWeight() {
        // Quiet (San Francisco) with body .medium -> two steps up is .bold
        let quietMedium = ReaderThemeResolved(basePreset: .quiet,
                                              customizedPreset: ReaderThemeCustom(fontWeight: .medium))
        // Charter body .bold -> two steps up is .black, which Charter has
        let charterBold = ReaderThemeResolved(basePreset: .linen,
                                              customizedPreset: ReaderThemeCustom(fontWeight: .bold, font: .charter))
        // Georgia body .bold -> .black is capped at Georgia's heaviest, .bold
        let georgiaBold = ReaderThemeResolved(basePreset: .linen,
                                              customizedPreset: ReaderThemeCustom(fontWeight: .bold, font: .georgia))

        #expect(quietMedium.emphasisWeight(minimum: .semibold) == .bold)
        #expect(quietMedium.emphasisWeight(minimum: .bold) == .bold)
        #expect(charterBold.emphasisWeight(minimum: .semibold) == .black)
        #expect(georgiaBold.emphasisWeight(minimum: .bold) == .bold)
    }

    /// When the font lacks the emphasis weight, the next heavier weight it has is used, never a
    /// lighter one: Seravek has no Semibold, so the divine name is Bold, not Medium
    @MainActor
    @Test func emphasisRoundsUpToAvailableWeight() {
        let seravek = ReaderThemeResolved(basePreset: .linen,
                                          customizedPreset: ReaderThemeCustom(font: .seravek))

        #expect(seravek.emphasisWeight(minimum: .semibold) == .bold)
        #expect(resolve(seravek.divineNameFont).isBold)
    }

    // MARK: Title Font

    /// Psalm titles are bold: with a regular body (Classic, New York) the title font is body bold
    @MainActor
    @Test func titleFontIsBoldForRegularBody() {
        let classic = ReaderThemeResolved(basePreset: .classic)

        #expect(resolve(classic.titleFont) == resolve(.system(.body, design: .serif, weight: .bold)))
    }

    /// The title stays heavier than a heavy body, the same way the divine name does: Charter with
    /// a bold body gets Black; Seravek (no Semibold) is still bold
    @MainActor
    @Test func titleFontUsesEmphasisWeight() {
        let charterBold = ReaderThemeResolved(basePreset: .linen,
                                              customizedPreset: ReaderThemeCustom(fontWeight: .bold, font: .charter))
        let seravek = ReaderThemeResolved(basePreset: .linen,
                                          customizedPreset: ReaderThemeCustom(font: .seravek))

        #expect(resolve(charterBold.titleFont) == resolve(charterBold.font(.body, weight: .black)))
        #expect(resolve(seravek.titleFont).isBold)
    }

    // MARK: Marker Baseline Offset

    /// Classic (New York) gets the same raise as the old serif-only calculation
    @MainActor
    @Test(arguments: [DynamicTypeSize.large, .xxxLarge, .accessibility3])
    func markerOffsetMatchesOldValueForNewYork(dynamicTypeSize: DynamicTypeSize) {
        let classic = ReaderThemeResolved(basePreset: .classic)

        #expect(abs(classic.markerBaselineOffset(dynamicTypeSize: dynamicTypeSize)
                    - oldSerifMarkerOffset(dynamicTypeSize)) < 0.001)
    }

    /// For every preset and font, the raised verse label and marker never reach above the
    /// body text's ascent (a taller ascent would push that line down and make spacing uneven)
    @MainActor
    @Test(arguments: [DynamicTypeSize.large, .xxxLarge, .accessibility3])
    func markerNeverRisesAboveBodyAscent(dynamicTypeSize: DynamicTypeSize) {
        for preset in ReaderTheme.allCases {
            for font in ReaderThemeFont.allCases {
                let themeResolved = ReaderThemeResolved(basePreset: preset,
                                                        customizedPreset: ReaderThemeCustom(font: font))
                let offset = themeResolved.markerBaselineOffset(dynamicTypeSize: dynamicTypeSize)
                let bodyAscent = ascent(themeResolved.scriptureFont, dynamicTypeSize)

                #expect(offset > 0, "\(preset) \(font)")
                #expect(offset + ascent(themeResolved.verseLabelFont, dynamicTypeSize) <= bodyAscent + 0.001,
                        "\(preset) \(font) verse label")
                #expect(offset + ascent(themeResolved.markerFont, dynamicTypeSize) <= bodyAscent + 0.001,
                        "\(preset) \(font) marker")
            }
        }
    }

    /// A named font is measured itself: Palatino has less room above its caption2 than
    /// New York, so its raise is smaller than Classic's
    @MainActor
    @Test func namedFontGetsItsOwnMarkerOffset() {
        let classic = ReaderThemeResolved(basePreset: .classic)
        let classicPalatino = ReaderThemeResolved(basePreset: .classic,
                                                  customizedPreset: ReaderThemeCustom(font: .palatino))

        #expect(classicPalatino.markerBaselineOffset(dynamicTypeSize: .large)
                < classic.markerBaselineOffset(dynamicTypeSize: .large))
    }

    // MARK: Line Height

    /// Every preset starts at 1.35x the font's line height, so nothing moves yet
    @MainActor
    @Test func presetLineSpacingIsDefault() {
        for preset in ReaderTheme.allCases {
            #expect(preset.lineSpacingPercent == 135)
            #expect(ReaderThemeResolved(basePreset: preset).lineSpacingPercent == 135)
        }
    }

    /// Line height = line spacing x the Scripture font's natural line height at that size;
    /// for Classic (New York) at the default size that is about 30pt
    @MainActor
    @Test(arguments: [DynamicTypeSize.large, .xxxLarge, .accessibility3])
    func lineHeightIsSpacingTimesFontLineHeight(dynamicTypeSize: DynamicTypeSize) {
        let classic = ReaderThemeResolved(basePreset: .classic)
        let expected = naturalLineHeight(classic.scriptureFont, dynamicTypeSize) * 1.35

        #expect(abs(classic.lineHeight(dynamicTypeSize: dynamicTypeSize) - expected) < 0.01)
        if dynamicTypeSize == .large {
            #expect(abs(classic.lineHeight(dynamicTypeSize: .large) - 30) < 0.5)
        }
    }

    /// A font with a taller natural line (Iowan) gets taller lines; a shorter one (Palatino) shorter
    @MainActor
    @Test func lineHeightFollowsFont() {
        let classic = ReaderThemeResolved(basePreset: .classic)
        let iowan = ReaderThemeResolved(basePreset: .classic, customizedPreset: ReaderThemeCustom(font: .iowan))
        let palatino = ReaderThemeResolved(basePreset: .classic, customizedPreset: ReaderThemeCustom(font: .palatino))

        #expect(iowan.lineHeight(dynamicTypeSize: .large) > classic.lineHeight(dynamicTypeSize: .large))
        #expect(palatino.lineHeight(dynamicTypeSize: .large) < classic.lineHeight(dynamicTypeSize: .large))
    }

    /// A line spacing edit replaces the preset's 135, and the line height follows it
    @MainActor
    @Test func lineSpacingEditReplacesPreset() {
        var edits = ReaderThemeCustom()
        edits.lineSpacingPercent = 150
        let folio = ReaderThemeResolved(basePreset: .folio, customizedPreset: edits)
        let expected = naturalLineHeight(folio.scriptureFont, .large) * 1.5

        #expect(folio.lineSpacingPercent == 150)
        #expect(abs(folio.lineHeight(dynamicTypeSize: .large) - expected) < 0.01)
    }

    /// A saved value outside 100...200 (bad data, or a newer build's range) is clamped,
    /// so lines never overlap and never spread past 2x
    @MainActor
    @Test func lineSpacingIsClamped() {
        var tooTight = ReaderThemeCustom()
        tooTight.lineSpacingPercent = 50
        var tooLoose = ReaderThemeCustom()
        tooLoose.lineSpacingPercent = 300

        #expect(ReaderThemeResolved.lineSpacingPercentRange == 100...200)
        #expect(ReaderThemeResolved(basePreset: .folio, customizedPreset: tooTight).lineSpacingPercent == 100)
        #expect(ReaderThemeResolved(basePreset: .folio, customizedPreset: tooLoose).lineSpacingPercent == 200)
    }

    /// Edits saved before line spacing and margins existed load with neither edit
    @Test func oldEditsLoadWithoutLayoutEdits() throws {
        let savedBefore5c = Data(#"{"font":"charter","fontWeight":"bold"}"#.utf8)
        let edits = try JSONDecoder().decode(ReaderThemeCustom.self, from: savedBefore5c)

        #expect(edits.lineSpacingPercent == nil)
        #expect(edits.marginPoints == nil)
        #expect(edits.characterSpacingPercent == nil)
        #expect(edits.wordSpacingPercent == nil)
        #expect(edits.font == .charter)
    }

    // MARK: Margins

    /// Every preset starts at today's 24pt margin
    @MainActor
    @Test func presetMarginIsDefault() {
        for preset in ReaderTheme.allCases {
            #expect(preset.marginPoints == 24)
            #expect(ReaderThemeResolved(basePreset: preset).marginPoints == 24)
        }
    }

    /// A margin edit replaces the preset's 24
    @MainActor
    @Test func marginEditReplacesPreset() {
        var edits = ReaderThemeCustom()
        edits.marginPoints = 40

        #expect(ReaderThemeResolved(basePreset: .folio, customizedPreset: edits).marginPoints == 40)
    }

    /// A saved margin outside 12...48 is clamped, so text never touches the screen edge
    /// and never shrinks to a narrow column
    @MainActor
    @Test func marginIsClamped() {
        var tooNarrow = ReaderThemeCustom()
        tooNarrow.marginPoints = 4
        var tooWide = ReaderThemeCustom()
        tooWide.marginPoints = 100

        #expect(ReaderThemeResolved.marginPointsRange == 12...48)
        #expect(ReaderThemeResolved(basePreset: .folio, customizedPreset: tooNarrow).marginPoints == 12)
        #expect(ReaderThemeResolved(basePreset: .folio, customizedPreset: tooWide).marginPoints == 48)
    }

    // MARK: Text Size

    /// With no text size step, Scripture uses the system Dynamic Type size unchanged
    @MainActor
    @Test func zeroStepKeepsSystemSize() {
        let folio = ReaderThemeResolved(basePreset: .folio)

        #expect(folio.textSizeStep == 0)
        for size in DynamicTypeSize.allCases {
            #expect(folio.scriptureDynamicTypeSize(for: size) == size)
        }
    }

    /// Each step moves Scripture one Dynamic Type size up or down from the system size
    @MainActor
    @Test func stepMovesScriptureSize() {
        let twoUp = ReaderThemeResolved(basePreset: .folio, textSizeStep: 2)
        let oneDown = ReaderThemeResolved(basePreset: .folio, textSizeStep: -1)

        #expect(twoUp.scriptureDynamicTypeSize(for: .large) == .xxLarge)
        #expect(twoUp.scriptureDynamicTypeSize(for: .xxxLarge) == .accessibility2)
        #expect(oneDown.scriptureDynamicTypeSize(for: .large) == .medium)
    }

    /// The step stays within -3...5, and the size never goes past either end of Apple's table
    @MainActor
    @Test func textSizeIsClamped() {
        #expect(ReaderThemeResolved.textSizeStepRange == -3...5)
        // 9 counts as 5: large + 5 = accessibility2 (not accessibility5)
        #expect(ReaderThemeResolved(basePreset: .folio, textSizeStep: 9)
            .scriptureDynamicTypeSize(for: .large) == .accessibility2)
        // -9 counts as -3: xxxLarge - 3 = large (not xSmall)
        #expect(ReaderThemeResolved(basePreset: .folio, textSizeStep: -9)
            .scriptureDynamicTypeSize(for: .xxxLarge) == .large)

        #expect(ReaderThemeResolved(basePreset: .folio, textSizeStep: 1)
            .scriptureDynamicTypeSize(for: .accessibility5) == .accessibility5)
        #expect(ReaderThemeResolved(basePreset: .folio, textSizeStep: -1)
            .scriptureDynamicTypeSize(for: .xSmall) == .xSmall)
    }

    /// At the default system size, an A/A button turns off only at its step limit
    @MainActor
    @Test func textSizeButtonsDisableAtStepLimits() {
        let noStep = ReaderThemeResolved(basePreset: .folio)
        let maxStep = ReaderThemeResolved(basePreset: .folio, textSizeStep: 5)
        let minStep = ReaderThemeResolved(basePreset: .folio, textSizeStep: -3)

        #expect(noStep.canIncreaseTextSize(at: .large))
        #expect(noStep.canDecreaseTextSize(at: .large))
        #expect(!maxStep.canIncreaseTextSize(at: .large))
        #expect(maxStep.canDecreaseTextSize(at: .large))
        #expect(minStep.canIncreaseTextSize(at: .large))
        #expect(!minStep.canDecreaseTextSize(at: .large))
    }

    /// A button also turns off when Scripture is already at the largest or smallest Dynamic Type
    /// size, even below the step limit, because another tap would change nothing
    @MainActor
    @Test func textSizeButtonsDisableAtTableEnds() {
        // system already at the largest size
        #expect(!ReaderThemeResolved(basePreset: .folio).canIncreaseTextSize(at: .accessibility5))

        // accessibility3 + 2 = accessibility5 (largest), though 2 is below the limit of 5
        #expect(!ReaderThemeResolved(basePreset: .folio, textSizeStep: 2).canIncreaseTextSize(at: .accessibility3))

        // small - 1 = xSmall (smallest), though -1 is above the limit of -3
        let oneDown = ReaderThemeResolved(basePreset: .folio, textSizeStep: -1)
        #expect(!oneDown.canDecreaseTextSize(at: .small))
        #expect(oneDown.canDecreaseTextSize(at: .large))
    }

    /// With no step, the percent label reads 100 at every system size
    @MainActor
    @Test(arguments: DynamicTypeSize.allCases)
    func textSizePercentIsHundredWithoutStep(dynamicTypeSize: DynamicTypeSize) {
        #expect(ReaderThemeResolved(basePreset: .classic).textSizePercent(at: dynamicTypeSize) == 100)
    }

    /// The percent is Scripture's point size over the system size's point size, rounded:
    /// at Large (17pt), +1 is 19pt (112), +2 is 21pt (124), -1 is 16pt (94)
    @MainActor
    @Test func textSizePercentFollowsStep() {
        func percent(_ step: Int) -> Int {
            ReaderThemeResolved(basePreset: .classic, textSizeStep: step).textSizePercent(at: .large)
        }

        #expect(percent(1) == 112)
        #expect(percent(2) == 124)
        #expect(percent(-1) == 94)
    }

    /// The percent is measured on the Scripture font itself: named fonts scale less than the
    /// system font above Large (Seravek is 20pt at xxLarge, the system font 21pt), so the same
    /// step reads 118 on Folio and 124 on Classic
    @MainActor
    @Test func textSizePercentUsesScriptureFont() {
        let classic = ReaderThemeResolved(basePreset: .classic, textSizeStep: 2)
        let folio = ReaderThemeResolved(basePreset: .folio, textSizeStep: 2)

        #expect(classic.textSizePercent(at: .large) == 124)
        #expect(folio.textSizePercent(at: .large) == 118)
    }

    /// When the system is already at the largest size, a step changes nothing, so the label reads 100
    @MainActor
    @Test func textSizePercentIsHundredAtTableEnd() {
        let oneUp = ReaderThemeResolved(basePreset: .classic, textSizeStep: 1)

        #expect(oneUp.textSizePercent(at: .accessibility5) == 100)
    }

    // MARK: Character and Word Spacing

    /// Every preset starts with no extra spacing, so nothing moves yet
    @MainActor
    @Test func presetSpacingIsZero() {
        for preset in ReaderTheme.allCases {
            let themeResolved = ReaderThemeResolved(basePreset: preset)

            #expect(preset.characterSpacingPercent == 0)
            #expect(preset.wordSpacingPercent == 0)
            #expect(themeResolved.characterSpacingPercent == 0)
            #expect(themeResolved.wordSpacingPercent == 0)
        }
    }

    /// Spacing edits replace the preset's values, each on its own
    @MainActor
    @Test func spacingEditsReplacePreset() {
        var edits = ReaderThemeCustom()
        edits.characterSpacingPercent = 10
        let characterOnly = ReaderThemeResolved(basePreset: .folio, customizedPreset: edits)

        edits.wordSpacingPercent = 15
        let both = ReaderThemeResolved(basePreset: .folio, customizedPreset: edits)

        #expect(characterOnly.characterSpacingPercent == 10)
        #expect(characterOnly.wordSpacingPercent == 0)
        #expect(both.wordSpacingPercent == 15)
    }

    /// Saved spacing outside 0...20 is clamped, so letters never crowd and words never spread too far
    @MainActor
    @Test func spacingIsClamped() {
        var low = ReaderThemeCustom()
        low.characterSpacingPercent = -5
        low.wordSpacingPercent = -5
        var high = ReaderThemeCustom()
        high.characterSpacingPercent = 50
        high.wordSpacingPercent = 50

        #expect(ReaderThemeResolved.characterSpacingPercentRange == 0...20)
        #expect(ReaderThemeResolved.wordSpacingPercentRange == 0...20)
        #expect(ReaderThemeResolved(basePreset: .folio, customizedPreset: low).characterSpacingPercent == 0)
        #expect(ReaderThemeResolved(basePreset: .folio, customizedPreset: low).wordSpacingPercent == 0)
        #expect(ReaderThemeResolved(basePreset: .folio, customizedPreset: high).characterSpacingPercent == 20)
        #expect(ReaderThemeResolved(basePreset: .folio, customizedPreset: high).wordSpacingPercent == 20)
    }

    /// No spacing edits: zero extra points at every size
    @MainActor
    @Test func zeroSpacingAddsNoPoints() {
        let folio = ReaderThemeResolved(basePreset: .folio)

        for size in [DynamicTypeSize.large, .accessibility3] {
            #expect(folio.characterSpacing(dynamicTypeSize: size) == 0)
            #expect(folio.wordSpacing(dynamicTypeSize: size) == 0)
        }
    }

    /// Spacing is a percent of the scripture font's point size: 10% of Folio's 17pt body is 1.7pt
    @MainActor
    @Test func spacingIsPercentOfPointSize() {
        var edits = ReaderThemeCustom()
        edits.characterSpacingPercent = 10
        edits.wordSpacingPercent = 20
        let folio = ReaderThemeResolved(basePreset: .folio, customizedPreset: edits)
        let pointSize = resolve(folio.scriptureFont, .large).pointSize

        #expect(pointSize == 17)
        #expect(abs(folio.characterSpacing(dynamicTypeSize: .large) - 1.7) < 0.001)
        #expect(abs(folio.wordSpacing(dynamicTypeSize: .large) - 3.4) < 0.001)
    }

    /// Spacing grows with text size, so a larger Dynamic Type size (or A/A step) keeps the same look
    @MainActor
    @Test func spacingGrowsWithTextSize() {
        var edits = ReaderThemeCustom()
        edits.characterSpacingPercent = 10
        let folio = ReaderThemeResolved(basePreset: .folio, customizedPreset: edits)

        #expect(folio.characterSpacing(dynamicTypeSize: .accessibility3)
                > folio.characterSpacing(dynamicTypeSize: .large))
    }

    // MARK: Resolved Font Weight

    /// With no weight edit, the preset's weight is used with any font: Ink's .bold stays .bold on
    /// its own Athelas, on the system font and on Georgia (each has a bold face)
    @MainActor
    @Test func presetWeightFollowsChosenFont() {
        let ink = ReaderThemeResolved(basePreset: .ink)
        let inkSystem = ReaderThemeResolved(basePreset: .ink,
                                            customizedPreset: ReaderThemeCustom(font: .system))
        let inkGeorgia = ReaderThemeResolved(basePreset: .ink,
                                             customizedPreset: ReaderThemeCustom(font: .georgia))

        #expect(ink.font == .athelas)
        #expect(ink.fontWeight == .bold)
        #expect(inkSystem.fontWeight == .bold)
        #expect(inkGeorgia.fontWeight == .bold)
    }

    /// A weight edit is snapped for drawing but saved as chosen, so it returns with a font that has it
    @MainActor
    @Test func weightEditSurvivesFontChange() {
        var edits = ReaderThemeCustom()
        edits.fontWeight = .light
        edits.font = .seravek
        let onSeravek = ReaderThemeResolved(basePreset: .linen, customizedPreset: edits)

        edits.font = .georgia
        let onGeorgia = ReaderThemeResolved(basePreset: .linen, customizedPreset: edits)

        #expect(onSeravek.fontWeight == .light)
        #expect(onGeorgia.fontWeight == .regular)
        #expect(onGeorgia.customizedPreset?.fontWeight == .light)
    }

    /// The Weight picker's options follow the font and design, and the drawn weight is always one of them
    @MainActor
    @Test func fontWeightIsAlwaysAnAvailableWeight() {
        let folioCharter = ReaderThemeResolved(basePreset: .folio,
                                               customizedPreset: ReaderThemeCustom(font: .charter))
        #expect(ReaderThemeResolved(basePreset: .classic).availableFontWeights
                == [.regular, .medium, .semibold, .bold, .heavy, .black])
        #expect(ReaderThemeResolved(basePreset: .folio).availableFontWeights
                == [.ultraLight, .light, .regular, .medium, .bold])
        #expect(folioCharter.availableFontWeights == [.regular, .bold, .black])

        for preset in ReaderTheme.allCases {
            for font in ReaderThemeFont.allCases {
                for design in ReaderThemeCustomFontDesign.allCases {
                    // nil = no weight edit, so the preset's weight is snapped too
                    for weight in [nil] + ReaderThemeCustomFontWeight.allCases.map(Optional.some) {
                        var edits = ReaderThemeCustom()
                        edits.font = font
                        edits.fontDesign = design
                        edits.fontWeight = weight
                        let themeResolved = ReaderThemeResolved(basePreset: preset, customizedPreset: edits)

                        #expect(themeResolved.availableFontWeights.contains(themeResolved.fontWeight),
                                "\(preset) \(font) \(design) \(String(describing: weight))")
                    }
                }
            }
        }
    }

    // MARK: Helpers

    /// Natural line height (ascent + descent + leading) of a font as drawn at a Dynamic Type size
    private func naturalLineHeight(_ font: Font, _ dynamicTypeSize: DynamicTypeSize) -> CGFloat {
        let ctFont = resolve(font, dynamicTypeSize).ctFont
        return CTFontGetAscent(ctFont) + CTFontGetDescent(ctFont) + CTFontGetLeading(ctFont)
    }

    /// Ascent (height above the baseline) of a font as drawn at a Dynamic Type size
    private func ascent(_ font: Font, _ dynamicTypeSize: DynamicTypeSize) -> CGFloat {
        CTFontGetAscent(resolve(font, dynamicTypeSize).ctFont)
    }

    /// The pre-5b-12 `PassageTextRenderer.markerBaselineOffset`: always measured the serif design
    @MainActor
    private func oldSerifMarkerOffset(_ dynamicTypeSize: DynamicTypeSize) -> CGFloat {
        let traits = UITraitCollection(preferredContentSizeCategory: UIContentSizeCategory(dynamicTypeSize))
        func serifFont(_ style: UIFont.TextStyle) -> UIFont {
            let descriptor = UIFontDescriptor.preferredFontDescriptor(withTextStyle: style, compatibleWith: traits)
            return UIFont(descriptor: descriptor.withDesign(.serif) ?? descriptor, size: 0)
        }

        let available = serifFont(.body).ascender - serifFont(.caption2).ascender
        return min(UIFontMetrics(forTextStyle: .body).scaledValue(for: 6, compatibleWith: traits), available)
    }

    /// Family name of the face a font draws at the default Dynamic Type size
    private func familyName(_ font: Font) -> String {
        CTFontCopyFamilyName(resolve(font).ctFont) as String
    }

    /// PostScript name of the face a font draws at body size
    private func faceName(_ font: ReaderThemeFont, _ design: Font.Design, _ weight: Font.Weight) -> String {
        CTFontCopyPostScriptName(resolve(font.font(.body, design: design, weight: weight)).ctFont) as String
    }

    /// Environment with only the color scheme set
    private func environment(_ colorScheme: ColorScheme) -> EnvironmentValues {
        var environment = EnvironmentValues()
        environment.colorScheme = colorScheme
        return environment
    }

    /// Font as drawn at a Dynamic Type size (default `.large`)
    private func resolve(_ font: Font, _ dynamicTypeSize: DynamicTypeSize = .large) -> Font.Resolved {
        var environment = EnvironmentValues()
        environment.dynamicTypeSize = dynamicTypeSize
        return font.resolve(in: environment.fontResolutionContext)
    }

    /// Components match within 1/255; colors pass through 8-bit UIColor values, so exact `==` fails
    private func isClose(_ actual: Color.Resolved, _ expected: Color.Resolved) -> Bool {
        let tolerance: Float = 1.0 / 255.0
        return abs(actual.red - expected.red) <= tolerance
            && abs(actual.green - expected.green) <= tolerance
            && abs(actual.blue - expected.blue) <= tolerance
            && abs(actual.opacity - expected.opacity) <= tolerance
    }
}
