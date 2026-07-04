//
//  SimulatorAccessibilityBridge.swift
//  SimpodHelper
//
//  Created by Tomiwa Idowu on 6/9/26.
//
//  Implementation is split across:
//    - SimulatorAccessibilityBridge.swift             – this file: type, constants, public API
//    - SimulatorAccessibilityBridge+Tree.swift        – context lifecycle + recursive tree build
//    - SimulatorAccessibilityBridge+GridSweep.swift   – hit-test sweep that fills in hidden elements
//    - SimulatorAccessibilityBridge+Translator.swift  – AXPTranslator FFI + attribute readers + token stamping
//    - SimulatorAccessibilityBridge+Device.swift      – CoreSimulator device + screen-size lookup
//    - BridgeRelay.swift                              – AXP bridge-token delegate
//

import CoreGraphics
import Foundation
import ObjectiveC

/// Single entry point for capturing a booted iOS Simulator's
/// accessibility tree as JSON.
///
/// ## Thread Safety
///
/// Framework loading and translator wiring happen **once per
/// process** via `static let` (language-guaranteed thread safety).
/// Per-call state (token ↔ device mapping) is guarded by an
/// `NSLock` inside the shared `BridgeRelay`.
///
/// ## Usage
///
/// ```swift
/// let inspector = SimulatorAccessibilityBridge(udid: "XXXXXXXX-…")
/// let json = try inspector.describeUI()              // → Data
/// let hit  = try inspector.describeAt(x: 200, y: 400) // → Data
/// ```
final class SimulatorAccessibilityBridge: NSObject, @unchecked Sendable {

    // MARK: Nested types

    /// Projects a `CGRect` from macOS host-window coordinates (where
    /// AXPTranslator reports frames) into iOS device-point coordinates
    /// (matching the gesture wire). The math is a width-uniform scale
    /// plus vertical centering offset (letterbox compensation).
    struct ScreenProjection: Equatable, Sendable {
        let rootFrame: CGRect
        let deviceSize: CGSize

        /// Host-window rect → device-point rect.
        func project(_ macFrame: CGRect) -> CGRect {
            guard rootFrame.width > 0, rootFrame.height > 0,
                  deviceSize.width > 0, deviceSize.height > 0 else {
                return macFrame
            }
            let scale = deviceSize.width / rootFrame.width
            let yOffset = (deviceSize.height - rootFrame.height * scale) / 2
            return CGRect(
                x: (macFrame.origin.x - rootFrame.origin.x) * scale,
                y: (macFrame.origin.y - rootFrame.origin.y) * scale + yOffset,
                width: macFrame.size.width * scale,
                height: macFrame.size.height * scale
            )
        }

        /// Inverse: device-point coordinate → host-window coordinate.
        /// Needed when feeding `objectAtPoint:` which works in host space.
        func unproject(_ devicePoint: CGPoint) -> CGPoint {
            guard rootFrame.width > 0, rootFrame.height > 0,
                  deviceSize.width > 0, deviceSize.height > 0 else {
                return devicePoint
            }
            let scale = deviceSize.width / rootFrame.width
            let yOffset = (deviceSize.height - rootFrame.height * scale) / 2
            return CGPoint(
                x: devicePoint.x / scale + rootFrame.origin.x,
                y: (devicePoint.y - yOffset) / scale + rootFrame.origin.y
            )
        }
    }

    /// Generates cell-centred sample points across the device screen
    /// for the hit-test sweep. Points inside `covered` rects (terminal
    /// leaves already captured by the recursive walk) are skipped.
    /// Emits **row-major from the top** so the status bar is probed
    /// first — even if the deadline cuts the sweep short.
    struct ProbeGrid: Equatable, Sendable {
        let width: Double
        let height: Double
        let step: Double
        let cap: Int

        func samplePoints(covered: [CGRect]) -> [CGPoint] {
            guard width > 0, height > 0, step > 0 else { return [] }
            var points: [CGPoint] = []
            var y = step / 2
            while y < height {
                var x = step / 2
                while x < width {
                    let p = CGPoint(x: x, y: y)
                    // Skip points already inside a known terminal leaf.
                    if !covered.contains(where: { $0.contains(p) }) {
                        points.append(p)
                        if points.count >= cap { return points }
                    }
                    x += step
                }
                y += step
            }
            return points
        }
    }

    /// Bundles the per-call state every AXP operation needs. Created
    /// by `withBridgeContext(_:)`, which owns the token lifecycle.
    struct BridgeContext {
        let translator: NSObject
        let token: String
        let rootElement: NSObject
        let projection: ScreenProjection
        let deadline: Date
    }

    // MARK: Constants

    /// Max recursion depth. Real iOS screens rarely exceed 20–30.
    static let maxDepth = 60
    /// Per-XPC timeout so a hung simulator doesn't block the caller.
    static let xpcTimeout: Double = 5.0
    /// Grid sweep: step size in device points.
    static let sweepStep: Double = 32
    /// Grid sweep: max number of hit-test probes.
    static let sweepCap: Int = 600
    /// Grid sweep: wall-clock budget (seconds). The recursive walk
    /// already produced a usable tree — this only caps the *extra*
    /// hit-test work.
    static let sweepBudget: Double = 2.5
    /// Grid sweep: per-point walk depth. Zero = just the leaf.
    /// A deeper walk fans out into dozens of XPC sub-requests per
    /// point, which can timeout before covering the full screen.
    static let sweepDepth: Int = 0

    // MARK: Instance properties

    /// The UDID of the target iOS Simulator.
    let udid: String

    /// Creates an accessibility inspector for the given simulator.
    /// - Parameter udid: The booted simulator's UUID string.
    init(udid: String) {
        self.udid = udid
        super.init()
    }

    // MARK: - Shared process-wide state

    // Framework loading and translator acquisition happen exactly
    // once per process. Swift `static let` guarantees thread-safe
    // lazy initialization.

    /// `true` once `dlopen` succeeds for the private framework.
    static let frameworkReady: Bool = {
        let path = "/System/Library/PrivateFrameworks/"
        + "AccessibilityPlatformTranslation.framework/"
        + "AccessibilityPlatformTranslation"
        if dlopen(path, RTLD_NOW | RTLD_GLOBAL) == nil {
            return false
        }
        return true
    }()

    /// Process-global `AXPTranslator` singleton, wired with our
    /// bridge-token delegate. `nil` if the framework didn't load.
    nonisolated(unsafe) static let sharedTranslator: NSObject? = {
        guard frameworkReady else { return nil }
        guard let cls = NSClassFromString("AXPTranslator") else { return nil }
        // Resolve +[AXPTranslator sharedInstance] via IMP to avoid
        // perform-selector retain/release ambiguity.
        let sel = NSSelectorFromString("sharedInstance")
        guard let metaCls = object_getClass(cls),
              let imp = class_getMethodImplementation(metaCls, sel) else {
            return nil
        }
        typealias Fn = @convention(c) (AnyClass, Selector) -> AnyObject?
        guard let inst = unsafeBitCast(imp, to: Fn.self)(cls, sel) as? NSObject else {
            return nil
        }
        // Critical: install the token delegate. Without this, every
        // frontmostApplication call returns nil because the translator
        // can't route XPC requests to any simulator device.
        inst.setValue(sharedRelay, forKey: "bridgeTokenDelegate")
        return inst
    }()

    /// Shared bridge-token delegate that routes AXP callbacks to
    /// the correct SimDevice based on a per-call UUID token.
    static let sharedRelay = BridgeRelay()

    /// `true` when the framework loaded and the translator is wired.
    static var isAvailable: Bool { sharedTranslator != nil }

    /// `true` when the translator supports the 3-arg `objectAtPoint:`
    /// selector needed for server-side hit-tests.
    static var supportsHitTest: Bool {
        guard let t = sharedTranslator else { return false }
        return t.responds(to: NSSelectorFromString(
            "objectAtPoint:displayId:bridgeDelegateToken:"
        ))
    }

    // MARK: - Public API

    /// Captures the full accessibility tree of the simulator's
    /// frontmost application and returns it as JSON `Data`.
    ///
    /// The JSON is an array containing one root element:
    /// ```json
    /// [{ "role": "AXApplication", "children": [...], ... }]
    /// ```
    ///
    /// Includes a grid-sweep pass that recovers elements hidden
    /// from the recursive walk (tab bars, nav bars, status bar).
    ///
    /// - Returns: Pretty-printed JSON `Data`.
    /// - Throws: `SimulatorAccessibilityError` on failure.
    func describeUI() throws -> Data {
        guard let tree = try buildFullTree() else {
            throw SimulatorAccessibilityError.noFrontmostApplication
        }
        return tree.jsonData
    }

    /// Hit-tests a single point on the simulator screen and returns
    /// the deepest element at that location as JSON `Data`.
    ///
    /// Coordinates are in iOS device points (origin top-left).
    ///
    /// - Parameters:
    ///   - x: Horizontal position in device points.
    ///   - y: Vertical position in device points.
    /// - Returns: JSON `Data` for the hit element, or the root if
    ///   nothing specific was found.
    /// - Throws: `SimulatorAccessibilityError` on failure.
    func describeAt(x: Double, y: Double) throws -> Data {
        // Prefer server-side hit-test (reaches elements the tree
        // walk can't — tab bar buttons, status bar glyphs, etc.).
        if Self.supportsHitTest,
           let node = try probeServerSide(x: x, y: y) {
            return node.jsonData
        }
        // Fallback: full tree walk + client-side hit-test.
        guard let tree = try buildFullTree() else {
            throw SimulatorAccessibilityError.noFrontmostApplication
        }
        let hit = tree.hitTest(px: x, py: y) ?? tree
        return hit.jsonData
    }
}
