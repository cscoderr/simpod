//
//  SimulatorAccessibilityBridge+GridSweep.swift
//  SimpodHelper
//
//  Created by Tomiwa Idowu on 6/9/26.
//
//  The hit-test sweep that fills in elements the recursive walk
//  can't reach (tab bars, nav bars, status bar). The recursive walk
//  is fast but misses anything iOS doesn't expose as a child;
//  `objectAtPoint:` reaches them — at the cost of one XPC per probe.
//

import CoreGraphics
import Foundation

extension SimulatorAccessibilityBridge {

    /// Probes a grid of screen points via `objectAtPoint:` to recover
    /// elements the recursive walk couldn't reach (childless
    /// containers, cross-process status bar, etc.). Merges
    /// discoveries into `base` at the correct tree depth.
    func sweepAndMerge(base: AXNode, ctx: BridgeContext) -> AXNode {
        // Honour the earlier of the two deadlines: the per-call XPC
        // limit, and a dedicated sweep budget. The sweep is the
        // optional extra work — we'd rather return an incomplete
        // sweep than blow past the call deadline.
        let sweepDeadline = min(
            ctx.deadline,
            Date().addingTimeInterval(Self.sweepBudget)
        )
        let grid = ProbeGrid(
            width: Double(ctx.projection.deviceSize.width),
            height: Double(ctx.projection.deviceSize.height),
            step: Self.sweepStep,
            cap: Self.sweepCap
        )
        // Skip points inside genuine content leaves — they're
        // already fully described. Containers stay probeable.
        let covered = base.leafFrames()
        let points = grid.samplePoints(covered: covered)
        var discovered: [AXNode] = []
        for point in points {
            if Date() >= sweepDeadline { break }
            if let node = probeElement(
                atDeviceX: Double(point.x),
                atDeviceY: Double(point.y),
                ctx: ctx, depthCap: Self.sweepDepth
            ) {
                discovered.append(node)
            }
        }
        // Graft discoveries under the deepest container that
        // holds each one (not flat at the root).
        return base.merging(extras: discovered)
    }

    /// Hit-test a single device-point and return the element there.
    func probeElement(
        atDeviceX x: Double, atDeviceY y: Double,
        ctx: BridgeContext, depthCap: Int
    ) -> AXNode? {
        // Map device-point → host-window coordinate for the AXP API.
        let hostPoint = ctx.projection.unproject(CGPoint(x: x, y: y))
        guard let hitTranslation = Self.resolveObjectAtPoint(
            translator: ctx.translator, point: hostPoint,
            displayId: 0, token: ctx.token
        ) else { return nil }
        Self.tagToken(ctx.token, on: hitTranslation)
        guard let hitElement = Self.convertToMacElement(
            translator: ctx.translator, translation: hitTranslation
        ) else { return nil }
        Self.tagElementTranslation(token: ctx.token, on: hitElement)
        // Only pre-stamp subtree when we'll actually walk children.
        if depthCap > 0 {
            Self.propagateToken(hitElement, token: ctx.token, cap: depthCap)
        }
        return Self.buildNode(
            from: hitElement,
            projection: ctx.projection,
            depthCap: depthCap,
            deadline: ctx.deadline
        )
    }
}
