//
//  SimulatorAccessibilityBridge+Tree.swift
//  SimpodHelper
//
//  Created by Tomiwa Idowu on 6/9/26.
//
//  The recursive walk that turns AXP element trees into AXNode
//  trees, plus the lifecycle wrapper that prepares the bridge
//  context (translator + frontmost app + projection + token).
//

import CoreGraphics
import Foundation

extension SimulatorAccessibilityBridge {

    // MARK: - Bridge context lifecycle

    /// Runs `body` inside a fully-prepared bridge context. Handles:
    /// - Token registration / unregistration (deferred cleanup)
    /// - Translator + frontmost-app resolution
    /// - Coordinate projection setup (host → device points)
    ///
    /// Returns `nil` when any setup step fails.
    func withBridgeContext<T>(
        _ body: (BridgeContext) throws -> T?
    ) throws -> T? {
        guard Self.isAvailable else {
            throw SimulatorAccessibilityError.frameworkUnavailable
        }
        guard let device = SimulatorHelper.findSimDevice(with: udid) else {
            throw SimulatorAccessibilityError.deviceNotFound(udid)
        }
        let token = UUID().uuidString
        let deadline = Date().addingTimeInterval(Self.xpcTimeout)
        Self.sharedRelay.register(device: device, token: token, deadline: deadline)
        defer { Self.sharedRelay.unregister(token: token) }
        guard let translator = Self.sharedTranslator else {
            throw SimulatorAccessibilityError.translatorUnavailable
        }
        // Get the frontmost application's translation object.
        guard let translation = Self.resolveFrontmostApp(
            translator: translator, token: token
        ) else {
            throw SimulatorAccessibilityError.noFrontmostApplication
        }
        Self.tagToken(token, on: translation)
        // Convert translation → mac platform element.
        guard let rootElement = Self.convertToMacElement(
            translator: translator, translation: translation
        ) else {
            throw SimulatorAccessibilityError.noFrontmostApplication
        }
        // Build coordinate projection from the root element's frame
        // and the device's logical screen size.
        let deviceSize = Self.resolveDeviceScreenSize(for: device)
        let rootFrame = Self.readFrame(of: rootElement)
        let projection = ScreenProjection(
            rootFrame: rootFrame, deviceSize: deviceSize
        )
        return try body(BridgeContext(
            translator: translator,
            token: token,
            rootElement: rootElement,
            projection: projection,
            deadline: deadline
        ))
    }

    // MARK: - Tree building

    /// Full tree: recursive walk + grid sweep merge.
    func buildFullTree() throws -> AXNode? {
        try withBridgeContext { ctx in
            // Pre-stamp the entire subtree with the bridge token
            // BEFORE walking. The translator re-reads the token for
            // every XPC sub-request — pre-stamping ensures every
            // node is ready before any attribute read fires.
            Self.tagElementTranslation(token: ctx.token, on: ctx.rootElement)
            Self.propagateToken(
                ctx.rootElement, token: ctx.token, cap: Self.maxDepth
            )
            // Recursive walk builds the base tree.
            let base = Self.buildNode(
                from: ctx.rootElement,
                projection: ctx.projection,
                depthCap: Self.maxDepth,
                deadline: ctx.deadline
            )
            // Grid sweep discovers elements the walk missed
            // (tab bars, nav bars, status bar, etc.).
            guard Self.supportsHitTest else { return base }
            return sweepAndMerge(base: base, ctx: ctx)
        }
    }

    /// Server-side single-point hit-test (for `describeAt`).
    func probeServerSide(x: Double, y: Double) throws -> AXNode? {
        try withBridgeContext { ctx in
            probeElement(
                atDeviceX: x, atDeviceY: y,
                ctx: ctx, depthCap: Self.maxDepth
            )
        }
    }

    /// Recursively builds a `AXNode` from an accessibility element
    /// by reading its attributes via KVC and walking `accessibilityChildren`.
    static func buildNode(
        from element: NSObject,
        projection: ScreenProjection,
        depthCap: Int,
        deadline: Date,
        depth: Int = 0
    ) -> AXNode {
        let role = readString(element, "accessibilityRole") ?? "AXUnknown"
        let macFrame = readFrame(of: element)
        let projected = projection.project(macFrame)
        // Recurse into children if within budget.
        let children: [AXNode]
        if depth >= depthCap || Date() >= deadline {
            children = []
        } else {
            children = readChildren(of: element).map {
                buildNode(
                    from: $0, projection: projection,
                    depthCap: depthCap, deadline: deadline,
                    depth: depth + 1
                )
            }
        }
        return AXNode(
            role: role,
            subrole:    readString(element, "accessibilitySubrole"),
            label:      readString(element, "accessibilityLabel"),
            value:      readStringOrNumber(element, "accessibilityValue"),
            identifier: readString(element, "accessibilityIdentifier"),
            title:      readString(element, "accessibilityTitle"),
            help:       readString(element, "accessibilityHelp"),
            frameX:  Double(projected.origin.x),
            frameY:  Double(projected.origin.y),
            frameWidth:  Double(projected.size.width),
            frameHeight: Double(projected.size.height),
            // Read both ObjC property name variants — different
            // AXPMacPlatformElement versions expose one or the other.
            enabled: readBool(element, "accessibilityEnabled", fallback: true)
            || readBool(element, "isAccessibilityEnabled", fallback: false),
            focused: readBool(element, "isAccessibilityFocused", fallback: false)
            || readBool(element, "accessibilityFocused", fallback: false),
            hidden:  readBool(element, "isAccessibilityHidden", fallback: false)
            || readBool(element, "accessibilityHidden", fallback: false),
            children: children
        )
    }
}
