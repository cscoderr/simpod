//
//  SimulatorAccessibilityBridge+Translator.swift
//  SimpodHelper
//
//  Created by Tomiwa Idowu on 6/9/26.
//
//  Everything that talks to the private AccessibilityPlatformTranslation
//  framework: KVC attribute readers, bridge-token stamping, and the
//  three AXPTranslator selectors we depend on. None of these have
//  Swift bindings — each one is a manual IMP cast.
//

import CoreGraphics
import Foundation
import ObjectiveC

extension SimulatorAccessibilityBridge {

    // MARK: - Element attribute readers
    // KVC (`value(forKey:)`) works because `AXPMacPlatformElement`
    // exposes standard accessibility properties as `@objc` — the
    // underlying AXP framework faults them in lazily via the
    // bridge delegate.

    /// Non-empty string, or `nil`.
    static func readString(
        _ obj: NSObject, _ key: String
    ) -> String? {
        guard let s = obj.value(forKey: key) as? String,
              !s.isEmpty else { return nil }
        return s
    }

    /// String, or NSNumber coerced to its stringValue. Covers
    /// sliders, progress views, page pickers that report numeric
    /// accessibility values.
    static func readStringOrNumber(
        _ obj: NSObject, _ key: String
    ) -> String? {
        let raw = obj.value(forKey: key)
        if let s = raw as? String { return s.isEmpty ? nil : s }
        if let n = raw as? NSNumber { return n.stringValue }
        return nil
    }

    /// Boolean from an NSNumber-valued KVC key, with a fallback
    /// when the key is absent or non-numeric.
    static func readBool(
        _ obj: NSObject, _ key: String, fallback: Bool
    ) -> Bool {
        if let n = obj.value(forKey: key) as? NSNumber {
            return n.boolValue
        }
        return fallback
    }

    /// `accessibilityFrame` returns `CGRect` (a C struct), which
    /// can't ride through KVC's type-erased return. Resolve via
    /// `class_getMethodImplementation` and a typed function-pointer
    /// cast.
    static func readFrame(of element: NSObject) -> CGRect {
        let sel = NSSelectorFromString("accessibilityFrame")
        guard element.responds(to: sel),
              let imp = class_getMethodImplementation(
                type(of: element), sel
              ) else {
            return .zero
        }
        typealias Fn = @convention(c) (AnyObject, Selector) -> CGRect
        return unsafeBitCast(imp, to: Fn.self)(element, sel)
    }

    /// `accessibilityChildren` → `[NSObject]`. Non-NSObject entries
    /// are silently dropped.
    static func readChildren(of element: NSObject) -> [NSObject] {
        guard let raw = element.value(forKey: "accessibilityChildren")
        else { return [] }
        if let arr = raw as? [NSObject] { return arr }
        return []
    }

    // MARK: - Token stamping
    // The translator re-reads `bridgeDelegateToken` on every
    // translation object for every XPC sub-request. Failing to
    // stamp means child-element reads silently return nil.

    /// Stamp a token onto a raw `AXPTranslationObject`.
    static func tagToken(_ token: String, on translation: NSObject) {
        translation.setValue(token, forKey: "bridgeDelegateToken")
    }

    /// Stamp a token onto an `AXPMacPlatformElement`'s underlying
    /// `.translation` sub-property.
    static func tagElementTranslation(
        token: String, on element: NSObject
    ) {
        if let trans = element.value(forKey: "translation") as? NSObject {
            tagToken(token, on: trans)
        }
    }

    /// Recursively pre-stamps every reachable child translation
    /// with `token`. Called **before** the walk so every node is
    /// ready when the walker reads its attributes.
    static func propagateToken(
        _ element: NSObject, token: String,
        cap: Int, depth: Int = 0
    ) {
        guard depth < cap else { return }
        for kid in readChildren(of: element) {
            tagElementTranslation(token: token, on: kid)
            propagateToken(kid, token: token, cap: cap, depth: depth + 1)
        }
    }

    // MARK: - AXPTranslator selectors

    /// `-[AXPTranslator frontmostApplicationWithDisplayId:bridgeDelegateToken:]`
    static func resolveFrontmostApp(
        translator: NSObject, token: String
    ) -> NSObject? {
        let sel = NSSelectorFromString(
            "frontmostApplicationWithDisplayId:bridgeDelegateToken:"
        )
        guard translator.responds(to: sel),
              let imp = class_getMethodImplementation(
                type(of: translator), sel
              ) else { return nil }
        typealias Fn = @convention(c) (
            AnyObject, Selector, UInt32, AnyObject
        ) -> AnyObject?
        return unsafeBitCast(imp, to: Fn.self)(
            translator, sel, 0, token as NSString
        ) as? NSObject
    }

    /// `-[AXPTranslator macPlatformElementFromTranslation:]`
    static func convertToMacElement(
        translator: NSObject, translation: NSObject
    ) -> NSObject? {
        let sel = NSSelectorFromString("macPlatformElementFromTranslation:")
        guard translator.responds(to: sel),
              let imp = class_getMethodImplementation(
                type(of: translator), sel
              ) else { return nil }
        typealias Fn = @convention(c) (
            AnyObject, Selector, AnyObject
        ) -> AnyObject?
        return unsafeBitCast(imp, to: Fn.self)(
            translator, sel, translation
        ) as? NSObject
    }

    /// `-[AXPTranslator objectAtPoint:displayId:bridgeDelegateToken:]`
    /// The 3-arg form takes the token as a parameter, so the
    /// dispatcher resolves correctly on the very first sub-request.
    static func resolveObjectAtPoint(
        translator: NSObject, point: CGPoint,
        displayId: UInt32, token: String
    ) -> NSObject? {
        let sel = NSSelectorFromString(
            "objectAtPoint:displayId:bridgeDelegateToken:"
        )
        guard translator.responds(to: sel),
              let imp = class_getMethodImplementation(
                type(of: translator), sel
              ) else { return nil }
        typealias Fn = @convention(c) (
            AnyObject, Selector, CGPoint, UInt32, AnyObject
        ) -> AnyObject?
        return unsafeBitCast(imp, to: Fn.self)(
            translator, sel, point, displayId, token as NSString
        ) as? NSObject
    }
}
