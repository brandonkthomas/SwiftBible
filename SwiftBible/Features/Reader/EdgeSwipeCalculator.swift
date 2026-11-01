//
//  EdgeSwipeCalculator.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 2026-10-31.
//

import Foundation

/// Calculates edge swipe positions for ReaderView's forward/back edge-swipe extension
struct EdgeSwipeCalculator {

    // MARK: Properties (Internal, Static)

    /// Required distance before we trigger threshold
    /// Internal (no modifier) so tests can read it via @testable import
    static let requiredHorizontalDragDistance: CGFloat = 112

    /// Maximum total distance we allow the circle to move
    /// Internal (no modifier) so tests can read it via @testable import
    static let maximumHorizontalDragDistance: CGFloat = 200

    /// Factor for end-of-drag circle position calculation "resistance"
    /// Internal (no modifier) so tests can read it via @testable import
    static let resistanceFactor: CGFloat = 0.3

    // MARK: Properties (Private)

    /// Always positive
    private let currentHorizontalDragDistance: CGFloat

    /// Are we going left/right (i.e. fw/back)?
    private let chapterNavigationDirection: ChapterNavigationDirection

    // MARK: Init

    init(currentHorizontalDragDistance: CGFloat,
         chapterNavigationDirection: ChapterNavigationDirection) {
        self.chapterNavigationDirection = chapterNavigationDirection

        // handle left/right authority in chokepoint (ctor)
        // normalize to a positive distance in the swipe's direction
        // allowed range: 0 to inf (drags opposite the swipe direction clamp to 0)
        self.currentHorizontalDragDistance = switch self.chapterNavigationDirection {
        // moving to right, from left edge: already positive
        case .previous: max(currentHorizontalDragDistance, 0)
        // moving to left, from right edge: negative, so flip sign
        case .next: max(-currentHorizontalDragDistance, 0)
        }
    }

    // MARK: Properties (Computed)

    /// Indicator point's (circle) horizontal offset from screen edge
    var circleOffset: CGFloat {
        let offset: CGFloat

        // we met threshold
        if currentHorizontalDragDistance >= Self.requiredHorizontalDragDistance {
            // take only amount beyond threshold & reduce its effectiveness
            let thresholdOverflow = abs(Self.requiredHorizontalDragDistance - currentHorizontalDragDistance)
            let additiveResistance = thresholdOverflow * Self.resistanceFactor
            offset = min(Self.requiredHorizontalDragDistance + additiveResistance, Self.maximumHorizontalDragDistance)
        // we have NOT met threshold yet
        } else {
            offset = currentHorizontalDragDistance
        }

        // finally, assign neg/pos again
        if self.chapterNavigationDirection == .previous {
            return offset
        } else {
            return -offset
        }
    }

    /// Total fill progress from 0 to 1
    var fillProgress: CGFloat {
        // what percent of the required threshold is our current value?
        min(max(currentHorizontalDragDistance / Self.requiredHorizontalDragDistance, 0), 1)
    }

    /// True if we've passed the required drag threshold
    var hasPassedThreshold: Bool {
        currentHorizontalDragDistance >= Self.requiredHorizontalDragDistance
    }
}
