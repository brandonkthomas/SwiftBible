//
//  ScaledMetricLimit.swift
//  SwiftBible
//

import SwiftUI
import UIKit

/// Upper limit for `@ScaledMetric(relativeTo: .body)` values in fixed-size chrome
/// (tab bar accessory, toolbar buttons, Settings icons)
///
/// Those places can't grow with the largest Dynamic Type sizes without clipping; pair the limit
/// with `.accessibilityShowsLargeContentViewer()` on controls so a long press still shows
/// them large
enum ScaledMetricLimit {

    /// `scaledValue`, but no larger than `baseValue` scaled for `largestSize`
    ///
    /// `@ScaledMetric` scales with `UIFontMetrics`, so this computes the same curve
    static func capped(_ scaledValue: CGFloat,
                       base baseValue: CGFloat,
                       at largestSize: DynamicTypeSize = .xxxLarge) -> CGFloat {
        let traits = UITraitCollection(preferredContentSizeCategory: UIContentSizeCategory(largestSize))
        let limit = UIFontMetrics(forTextStyle: .body).scaledValue(for: baseValue,
                                                                   compatibleWith: traits)
        return min(scaledValue, limit)
    }
}
