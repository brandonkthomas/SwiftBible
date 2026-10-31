//
//  EdgeSwipeCalculatorTests.swift
//  SwiftBibleTests
//
//  Created by Brandon Thomas on 2026-10-31.
//

import Foundation
import Testing
@testable import SwiftBible

struct EdgeSwipeCalculatorTests {

    // MARK: Tests

    /// Dragging opposite the swipe direction clamps to no movement
    @Test(arguments: ChapterNavigationDirection.allCases)
    func wrongDirectionProducesNoMovement(direction: ChapterNavigationDirection) {
        let calculator = EdgeSwipeCalculator(
            currentHorizontalDragDistance: -Self.required * Self.sign(for: direction),
            chapterNavigationDirection: direction
        )

        #expect(Self.isApproximatelyEqual(calculator.circleOffset, 0))
        #expect(Self.isApproximatelyEqual(calculator.fillProgress, 0))
        #expect(!calculator.hasPassedThreshold)
    }

    /// Halfway to the threshold: half progress, offset tracks the distance with the direction's sign
    @Test(arguments: ChapterNavigationDirection.allCases)
    func halfwayToThreshold(direction: ChapterNavigationDirection) {
        let distance = Self.required / 2
        let calculator = Self.calculator(distance: distance, direction: direction)

        #expect(Self.isApproximatelyEqual(calculator.fillProgress, 0.5))
        #expect(Self.isApproximatelyEqual(calculator.circleOffset, distance * Self.sign(for: direction)))
        #expect(!calculator.hasPassedThreshold)
    }

    /// Exactly at the threshold: passed, full progress, offset equals the threshold
    @Test(arguments: ChapterNavigationDirection.allCases)
    func exactlyAtThreshold(direction: ChapterNavigationDirection) {
        let calculator = Self.calculator(distance: Self.required, direction: direction)

        #expect(calculator.hasPassedThreshold)
        #expect(Self.isApproximatelyEqual(calculator.fillProgress, 1))
        #expect(Self.isApproximatelyEqual(calculator.circleOffset, Self.required * Self.sign(for: direction)))
    }

    /// A little past the threshold: offset moves with resistance, staying between threshold and raw distance
    @Test(arguments: ChapterNavigationDirection.allCases)
    func slightlyPastThresholdAppliesResistance(direction: ChapterNavigationDirection) {
        // overflow chosen so the resisted offset lands halfway between threshold and maximum (never capped)
        let overflow = (Self.maximum - Self.required) / 2 / Self.resistance
        let distance = Self.required + overflow
        let calculator = Self.calculator(distance: distance, direction: direction)
        let magnitude = abs(calculator.circleOffset)

        #expect(calculator.hasPassedThreshold)
        #expect(Self.isApproximatelyEqual(calculator.fillProgress, 1))
        #expect(calculator.circleOffset.sign == (direction == .previous ? .plus : .minus))
        #expect(magnitude < distance)
        #expect(magnitude > Self.required)
        #expect(Self.isApproximatelyEqual(magnitude, Self.required + overflow * Self.resistance))
    }

    /// Far past the threshold: offset is capped at the maximum
    @Test(arguments: ChapterNavigationDirection.allCases)
    func farPastThresholdIsCapped(direction: ChapterNavigationDirection) {
        // overflow large enough that resistance alone would exceed the maximum twice over
        let overflow = (Self.maximum - Self.required) * 2 / Self.resistance
        let calculator = Self.calculator(distance: Self.required + overflow, direction: direction)

        #expect(calculator.hasPassedThreshold)
        #expect(Self.isApproximatelyEqual(calculator.fillProgress, 1))
        #expect(Self.isApproximatelyEqual(calculator.circleOffset, Self.maximum * Self.sign(for: direction)))
    }

    // MARK: Helpers

    private static let required = EdgeSwipeCalculator.requiredHorizontalDragDistance
    private static let maximum = EdgeSwipeCalculator.maximumHorizontalDragDistance
    private static let resistance = EdgeSwipeCalculator.resistanceFactor

    /// Sign the gesture actually reports: dragging right from the left edge (previous) is positive,
    /// dragging left from the right edge (next) is negative
    private static func sign(for direction: ChapterNavigationDirection) -> CGFloat {
        direction == .previous ? 1 : -1
    }

    /// Builds a calculator from a positive distance, applying the real gesture sign for the direction
    private static func calculator(distance: CGFloat,
                                   direction: ChapterNavigationDirection) -> EdgeSwipeCalculator {
        EdgeSwipeCalculator(currentHorizontalDragDistance: distance * sign(for: direction),
                            chapterNavigationDirection: direction)
    }

    private static func isApproximatelyEqual(_ lhs: CGFloat, _ rhs: CGFloat, tolerance: CGFloat = 0.0001) -> Bool {
        abs(lhs - rhs) <= tolerance
    }
}
