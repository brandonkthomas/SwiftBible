//
//  TwoRowFlowLayout.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 2026-11-13.
//

import SwiftUI

/// Two-row horizontal flow
/// Items alternate rows in order (0, 2, 4… on top row; 1, 3, 5… on bottom -- same fill order
/// as two-row LazyHGrid) but each row packs its items L to R w/ their own widths
/// No shared cols unlike LazyHGrid; wide items in one row never stretch items below/above them
/// Intended to live inside a horizontal ScrollView
struct TwoRowFlowLayout: Layout {

    var spacing: CGFloat = 8

    /// Which row a given item index belongs to (top = 0, bottom = 1)
    private func row(for index: Int) -> Int { index % 2 }

    func sizeThatFits(proposal: ProposedViewSize,
                      subviews: Subviews,
                      cache: inout ()) -> CGSize {
        let metrics = rowMetrics(subviews)
        let width = max(metrics.width[0], metrics.width[1])
        let height = metrics.height[0]
        + (metrics.count[1] > 0 ? spacing + metrics.height[1] : 0)
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect,
                       proposal: ProposedViewSize,
                       subviews: Subviews,
                       cache: inout ()) {
        let metrics = rowMetrics(subviews)
        // Second row sits below tallest item in first row
        let rowY = [bounds.minY, bounds.minY + metrics.height[0] + spacing]
        var rowX = [bounds.minX, bounds.minX]

        for (index, subview) in subviews.enumerated() {
            let r = row(for: index)
            let size = subview.sizeThatFits(.unspecified)
            subview.place(at: CGPoint(x: rowX[r], y: rowY[r]),
                          anchor: .topLeading,
                          proposal: ProposedViewSize(size))
            rowX[r] += size.width + spacing
        }
    }

    /// Per-row total width/max height/item count
    private func rowMetrics(_ subviews: Subviews)
    -> (width: [CGFloat], height: [CGFloat], count: [Int]) {
        var width: [CGFloat] = [0, 0]
        var height: [CGFloat] = [0, 0]
        var count: [Int] = [0, 0]

        for (index, subview) in subviews.enumerated() {
            let r = row(for: index)
            let size = subview.sizeThatFits(.unspecified)
            width[r] += size.width + (count[r] > 0 ? spacing : 0)
            height[r] = max(height[r], size.height)
            count[r] += 1
        }
        return (width, height, count)
    }
}
