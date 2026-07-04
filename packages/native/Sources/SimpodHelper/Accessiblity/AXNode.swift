//
//  AXNode.swift
//  SimpodHelper
//
//  Created by Tomiwa Idowu on 6/9/26.
//
//  Standalone value type for the simulator UI snapshot, plus the
//  hit-test / leaf-classification / dedup-merge helpers that operate
//  on it. Pulled out of the bridge file so the recursive maths
//  isn't tangled with the AXP runtime plumbing.
//

import CoreGraphics
import Foundation

/// A snapshot of one element in the simulator's on-screen UI tree.
struct AXNode: Equatable, Sendable {
    let role: String
    let subrole: String?
    let label: String?
    let value: String?
    let identifier: String?
    let title: String?
    let help: String?
    let frameX: Double
    let frameY: Double
    let frameWidth: Double
    let frameHeight: Double
    let enabled: Bool
    let focused: Bool
    let hidden: Bool
    let children: [AXNode]
}

// MARK: - JSON projection

extension AXNode {
    /// Recursive dictionary matching the JSON schema. Sorted keys
    /// keep diffs and snapshot tests stable.
    var dictionary: [String: Any] {
        [
            "role":       role,
            "subrole":    subrole as Any? ?? NSNull(),
            "label":      label as Any? ?? NSNull(),
            "value":      value as Any? ?? NSNull(),
            "identifier": identifier as Any? ?? NSNull(),
            "title":      title as Any? ?? NSNull(),
            "help":       help as Any? ?? NSNull(),
            "frame": [
                "x":      frameX,
                "y":      frameY,
                "width":  frameWidth,
                "height": frameHeight,
            ],
            "enabled":  enabled,
            "focused":  focused,
            "hidden":   hidden,
            "children": children.map(\.dictionary),
        ]
    }

    /// Serialized JSON bytes, ready to return from an HTTP handler.
    var jsonData: Data {
        // Top-level array wrapping, matching `axe describe-ui` shape.
        let payload: [Any] = [dictionary]
        return (try? JSONSerialization.data(
            withJSONObject: payload, options: [.sortedKeys]
        )) ?? Data()
    }
}

// MARK: - Client-side hit-test

extension AXNode {
    /// Deepest descendant whose frame contains `(px, py)`, or `self`
    /// if no child claims the point. `nil` when the point is outside
    /// `self.frame` entirely.
    func hitTest(px: Double, py: Double) -> AXNode? {
        guard containsPoint(px, py) else { return nil }
        for child in children {
            if let hit = child.hitTest(px: px, py: py) { return hit }
        }
        return self
    }

    fileprivate func containsPoint(_ px: Double, _ py: Double) -> Bool {
        px >= frameX && px < frameX + frameWidth &&
        py >= frameY && py < frameY + frameHeight
    }
}

// MARK: - Leaf / container classification

extension AXNode {
    /// Roles that fully describe themselves as a single tappable
    /// element. A childless node with one of these roles is a
    /// genuine leaf — the grid sweep can skip its interior.
    /// Everything else (groups, scroll areas, toolbars, …) is
    /// treated as a *container* even when childless, because iOS
    /// frequently hides children from the recursive walk but
    /// still exposes them to positional hit-tests.
    static let terminalRoles: Set<String> = [
        "AXStaticText", "AXButton", "AXImage",
        "AXTextField", "AXTextArea", "AXSecureTextField",
        "AXLink", "AXCheckBox", "AXRadioButton",
        "AXSlider", "AXSwitch", "AXStepper",
        "AXValueIndicator", "AXPopUpButton",
        "AXMenuItem", "AXMenuButton",
        "AXDisclosureTriangle", "AXProgressIndicator",
    ]

    /// `true` when this node is a childless terminal element whose
    /// interior the grid sweep can safely skip.
    var isTerminal: Bool {
        children.isEmpty && Self.terminalRoles.contains(role)
    }

    /// Collects frames of genuine terminal leaves. The grid sweep
    /// skips points inside these — they're already fully described.
    /// Container frames are deliberately *not* included so the
    /// sweep can probe inside childless groups (tab bars, nav
    /// bars, toolbars) where hit-testable children hide.
    func leafFrames() -> [CGRect] {
        var out: [CGRect] = []
        collectLeafFrames(into: &out)
        return out
    }

    private func collectLeafFrames(into out: inout [CGRect]) {
        if isTerminal {
            out.append(CGRect(x: frameX, y: frameY,
                              width: frameWidth, height: frameHeight))
            return
        }
        for child in children { child.collectLeafFrames(into: &out) }
    }
}

// MARK: - Dedup + merge

extension AXNode {
    /// Stable identity for deduplication across the recursive walk
    /// and the grid sweep. Object identity is useless because the
    /// translator creates fresh translation objects per request.
    var fingerprint: String {
        let rx = frameX.rounded(), ry = frameY.rounded()
        let rw = frameWidth.rounded(), rh = frameHeight.rounded()
        return "\(role)|\(identifier ?? "")|\(label ?? "")|\(rx),\(ry),\(rw),\(rh)"
    }

    var center: (x: Double, y: Double) {
        (frameX + frameWidth / 2, frameY + frameHeight / 2)
    }

    /// Graft `extras` (from the grid sweep) into this tree. Each
    /// extra whose `fingerprint` isn't already in the tree is
    /// inserted under the **deepest existing container** whose
    /// frame contains its center. This keeps a discovered tab-bar
    /// button under its `AXGroup "Tab Bar"` parent — a flat append
    /// to the root would shadow it during client-side hit-tests.
    func merging(extras: [AXNode]) -> AXNode {
        var seen = Set<String>()
        collectFingerprints(into: &seen)
        let fresh = extras.filter { !seen.contains($0.fingerprint) }
        guard !fresh.isEmpty else { return self }
        // Remove duplicates within `fresh` itself.
        var deduped: [AXNode] = []
        for node in fresh {
            if seen.insert(node.fingerprint).inserted {
                deduped.append(node)
            }
        }
        return graft(deduped)
    }

    /// Recursively distribute `nodes` down to the deepest container
    /// that claims each one; unclaimed nodes attach to `self`.
    private func graft(_ nodes: [AXNode]) -> AXNode {
        var unclaimed = nodes
        let updatedChildren = children.map { child -> AXNode in
            let claimed = unclaimed.filter {
                child.containsPoint($0.center.x, $0.center.y)
            }
            if !claimed.isEmpty {
                unclaimed.removeAll {
                    child.containsPoint($0.center.x, $0.center.y)
                }
                return child.graft(claimed)
            }
            return child
        }
        return withChildren(updatedChildren + unclaimed)
    }

    private func collectFingerprints(into set: inout Set<String>) {
        set.insert(fingerprint)
        for child in children { child.collectFingerprints(into: &set) }
    }

    private func withChildren(_ newChildren: [AXNode]) -> AXNode {
        AXNode(
            role: role, subrole: subrole, label: label, value: value,
            identifier: identifier, title: title, help: help,
            frameX: frameX, frameY: frameY,
            frameWidth: frameWidth, frameHeight: frameHeight,
            enabled: enabled, focused: focused, hidden: hidden,
            children: newChildren
        )
    }
}
