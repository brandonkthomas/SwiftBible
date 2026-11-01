//
//  EdgeSwipeModifier.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 2026-10-31.
//

import OSLog
import SwiftUI

struct EdgeSwipeModifier: ViewModifier {

    // MARK: Properties

    /// Should we allow left-edge swipe?
    let canGoPrevious: Bool

    /// Should we allow right-edge swipe?
    let canGoNext: Bool

    /// What happens when we've released past the threshold?
    let onCommit: (ChapterNavigationDirection) async -> Void

    // MARK: Properties (Private)

    /// Disable scale animation if true
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion

    // MARK: Properties (Private, Haptics)

    @State private var triggerThresholdMetHaptic: Bool = false
    @State private var triggerOnCommitHaptic: Bool = false

    // MARK: Properties (Private, In-Drag)

    /// Which side of the screen are we on?
    @State private var dragEdge: Edge.Set?

    /// Realtime width of drag
    @State private var dragCircleOffset: CGFloat?

    /// Finger's current vertical position
    @State private var dragCurrentY: CGFloat?

    /// Where did we begin the drag?
    @State private var dragStartY: CGFloat?

    /// Have we passed the threshold yet?
    @State private var dragThresholdPassed: Bool?

    /// Fill % of circle (actually used for opacity right now
    @State private var dragFillProgress: CGFloat?

    // MARK: Properties (Private, Computed)

    /// X-offset adjusted to correct Edge
    private var dragFinalOffsetX: CGFloat {
        (dragCircleOffset ?? 0) + (dragEdge == .leading ? -Self.circleSize : Self.circleSize)
    }

    /// anchor at start Y, follow vertical finger movement w/ logarithmic resistance
    ///   Starts at `resistanceFactor` slope near startY, then flattens as distance grows:
    ///   resistanceFactor * scale * ln(1 + |delta| / scale)
    private var dragFinalOffsetY: CGFloat {
        let delta = (dragCurrentY ?? 0) - (dragStartY ?? 0)
        let scale = Self.verticalResistanceScale
        let resisted = EdgeSwipeCalculator.resistanceFactor * scale * log1p(abs(delta) / scale)
        return (dragStartY ?? 0) + (delta < 0 ? -resisted : resisted) - Self.circleSize
    }

    // MARK: Properties (Private, Constants)

    /// How wide is our touch interaction zone?
    private static let edgeWidth: CGFloat = 20

    private static let minimumDragDistance: CGFloat = 10

    private static let circleSize: CGFloat = 52

    /// Vertical distance (pt) where log resistance starts to noticeably flatten; lower = stiffer
    private static let verticalResistanceScale: CGFloat = 100

    private static let logger = Logger(subsystem: "SwiftBible", category: "EdgeSwipeModifier")

    // MARK: Functions (Implementations)

    /// Apply left/right overlays to the parent view
    func body(content: Content) -> some View {
        content
            // Views: 2 edge zones
            .overlay(alignment: .leading) {
                if canGoPrevious {
                    edgeZone(for: .previous)
                }
            }
            .overlay(alignment: .trailing) {
                if canGoNext {
                    edgeZone(for: .next)
                }
            }
            // View: indicator circle
            .overlay(alignment: dragEdge == .leading ? .topLeading : .topTrailing) {
                // only create view when we are mid-drag
                if dragFillProgress != nil {
                    indicatorCircle()
                        .transition(.opacity) // clean fade out animation
                }
            }
            // trigger haptics on threshold + commit
            .sensoryFeedback(
                .increase,
                trigger: triggerThresholdMetHaptic,
                condition: { old, new in
                    old == false && new == true
                })
            .sensoryFeedback(
                .selection,
                trigger: triggerOnCommitHaptic) // no condition: play every time
    }

    /// Create a tracked interaction zone on the left edge (full height) of the parent view
    private func edgeZone(for direction: ChapterNavigationDirection) -> some View {
        Rectangle()
            // size
//            .fill(.red.opacity(0.2)) // DEBUG
            .fill(.clear)
            .contentShape(Rectangle())
            .frame(width: Self.edgeWidth)
            .frame(maxHeight: .infinity)
            // gesture
            .gesture(
                DragGesture(minimumDistance: Self.minimumDragDistance)
                    .onChanged { value in
                        let calculator = EdgeSwipeCalculator(currentHorizontalDragDistance: value.translation.width,
                                                             chapterNavigationDirection: direction)
                        Self.logger.debug("circleOffset: \(calculator.circleOffset)")

                        let hasPassedThreshold = calculator.hasPassedThreshold

                        if hasPassedThreshold {
                            triggerThresholdMetHaptic = true // no .toggle(); dont want to spam
                        } else {
                            triggerThresholdMetHaptic = false
                        }

                        // adjust values
                        dragEdge = switch direction {
                        case .previous: .leading
                        case .next: .trailing
                        }
                        dragCircleOffset = calculator.circleOffset
                        dragCurrentY = value.location.y
                        dragStartY = value.startLocation.y // this value never changes; safe to assign unconditionally
                        dragThresholdPassed = hasPassedThreshold
                        dragFillProgress = calculator.fillProgress
                    }
                    .onEnded { value in
                        let calculator = EdgeSwipeCalculator(currentHorizontalDragDistance: value.translation.width,
                                                             chapterNavigationDirection: direction)
                        Self.logger.debug("hasPassedThreshold: \(calculator.hasPassedThreshold)")

                        if calculator.hasPassedThreshold {
                            Task { await onCommit(direction) }
                            triggerOnCommitHaptic.toggle()
                        }

                        // reset values
                        //   No need to reset these since we fade out the button on release
                        //   Resetting them here would cause jump
//                        dragEdge = nil
//                        dragCircleOffset = nil
//                        dragCurrentY = nil
//                        dragStartY = nil
//                        dragThresholdPassed = nil
                        withAnimation(.snappy(duration: 0.3)) {
                            dragFillProgress = nil
                        }

                        triggerThresholdMetHaptic = false
                        // triggerOnCommitHaptic: no need to reset since we used toggle()
                    }
            )

    }

    ///
    private func indicatorCircle() -> some View {
        Image(systemName: dragEdge == .leading ? "chevron.left" : "chevron.right")
            // circle
            .frame(width: Self.circleSize, height: Self.circleSize)
            .glassEffect(.clear.interactive().tint(dragThresholdPassed == true ? .accent.opacity(0.5) : .clear),
                         in: .circle)
            // symbol
            .imageScale(.large)
            .fontWeight(.bold)
            // scale on threshold passed
            .scaleEffect(dragThresholdPassed == true && !systemReduceMotion ? 1.3 : 1, anchor: .center)
            .animation(.bouncy(duration: 0.3, extraBounce: 0.3), value: dragThresholdPassed)
            // fade in/out
            .opacity(dragFillProgress ?? 0)
            // position
            .offset(x: dragFinalOffsetX, y: dragFinalOffsetY)
            // misc
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

extension View {
    /// @escaping marks a closure that is kept beyond the call
    func chapterEdgeSwipe(canGoPrevious: Bool,
                          canGoNext: Bool,
                          onCommit: @escaping (ChapterNavigationDirection) async -> Void) -> some View {
        modifier(EdgeSwipeModifier(canGoPrevious: canGoPrevious,
                                   canGoNext: canGoNext,
                                   onCommit: onCommit))
    }
}
