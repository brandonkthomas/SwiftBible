//
//  ReaderThemeFont.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 2026-11-14.
//

import Foundation
import SwiftUI

/// Available fonts for use in theme customizations
///
/// Raw values are saved with theme edits; never rename a case.
nonisolated enum ReaderThemeFont: String, Codable, CaseIterable, Identifiable {
    case system
    case athelas
    case charter
    case georgia
    case iowan
    case palatino
    case seravek
    case timesNewRoman

    /// Stable ID
    var id: String { rawValue }

    /// Font display name
    var displayName: String {
        switch self {
        case .system: return "System"
        case .athelas: return "Athelas"
        case .charter: return "Charter"
        case .georgia: return "Georgia"
        case .iowan: return "Iowan"
        case .palatino: return "Palatino"
        case .seravek: return "Seravek"
        case .timesNewRoman: return "Times New Roman"
        }
    }

    /// Optional family name
    ///
    /// `nil` = the system font; its look comes from the Style (design) choice
    /// Non-`nil` = an installed family, looked up by this name
    var familyName: String? {
        switch self {
        case .system: return nil
        case .athelas: return "Athelas"
        case .charter: return "Charter"
        case .georgia: return "Georgia"
        case .iowan: return "Iowan Old Style"
        case .palatino: return "Palatino"
        case .seravek: return "Seravek"
        case .timesNewRoman: return "Times New Roman"
        }
    }

    // MARK: Functions

    /// Weights that draw a distinct installed face, light to heavy
    ///
    /// Named families ignore `design`. For the system font, `.serif` (New York)
    /// has no UltraLight, Thin or Light
    func availableWeights(design: Font.Design) -> [ReaderThemeCustomFontWeight] {
        switch self {
        case .system:
            return design == .serif
                ? [.regular, .medium, .semibold, .bold, .heavy, .black]
                : ReaderThemeCustomFontWeight.allCases
        case .athelas, .georgia, .iowan, .palatino, .timesNewRoman:
            return [.regular, .bold]
        case .charter:
            return [.regular, .bold, .black]
        case .seravek:
            return [.ultraLight, .light, .regular, .medium, .bold]
        }
    }

    /// Available weight nearest to `weight` by position in `allCases`
    ///
    /// CoreText snaps by weight value, so Georgia `.medium` would draw Bold;
    /// snapping by position gives Regular... ties go to the lighter weight
    /// because `min(by:)` keeps first of equal elements
    func nearestWeight(to weight: ReaderThemeCustomFontWeight,
                       design: Font.Design) -> ReaderThemeCustomFontWeight {
        let allWeights = ReaderThemeCustomFontWeight.allCases
        // every case is in allCases, so these lookups never fall back to 0
        let target = allWeights.firstIndex(of: weight) ?? 0

        return availableWeights(design: design).min { lhs, rhs in
            let lhsDistance = abs((allWeights.firstIndex(of: lhs) ?? 0) - target)
            let rhsDistance = abs((allWeights.firstIndex(of: rhs) ?? 0) - target)
            return lhsDistance < rhsDistance
        } ?? weight
    }

    /// Font for a text style, design and weight
    ///
    /// The system font uses `design`; named families ignore it. Named families
    /// start at the system size for `textStyle` and scale with Dynamic Type
    /// relative to `.body` (scaling relative to small styles grows caption2
    /// past footnote at larger sizes); `weight` picks the family's closest face.
    func font(_ textStyle: Font.TextStyle,
              design: Font.Design,
              weight: Font.Weight) -> Font {
        guard let familyName else {
            return Font.system(textStyle, design: design, weight: weight)
        }

        // system size for this text style at the default Dynamic Type size
        let size = Font.system(textStyle)
            .resolve(in: EnvironmentValues().fontResolutionContext)
            .pointSize

        // family name (not a face name) so .weight can pick the matching face
        return Font.custom(familyName, size: size, relativeTo: .body)
            .weight(weight)
    }

    /// Font at a size that is never scaled by Dynamic Type
    ///
    /// For sizes the caller already scales (e.g. with `@ScaledMetric`);
    /// `Font.custom(_:size:)` would scale them a second time.
    func font(fixedSize size: CGFloat,
              design: Font.Design,
              weight: Font.Weight) -> Font {
        guard let familyName else {
            return Font.system(size: size, weight: weight, design: design)
        }

        return Font.custom(familyName, fixedSize: size)
            .weight(weight)
    }
}
