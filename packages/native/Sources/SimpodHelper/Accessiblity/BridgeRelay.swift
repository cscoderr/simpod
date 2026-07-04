//
//  BridgeRelay.swift
//  SimpodHelper
//
//  Created by Tomiwa Idowu on 6/9/26.
//
//  AXP "bridge token" delegate. The translator dispatches every
//  accessibility XPC call back to this object via three ObjC
//  selectors — we identify the target simulator by the per-call
//  token and forward the request synchronously over CoreSimulator.
//

import CoreGraphics
import Foundation
import ObjectiveC

/// Bridge-token delegate installed on the process-global
/// `AXPTranslator` via `bridgeTokenDelegate` KVC. Routes each
/// XPC accessibility request to the correct `SimDevice` based on
/// a per-call UUID token.
///
/// The translator calls three `@objc dynamic` methods:
///
/// 1. `…BridgeCallbackWithToken:` — returns a block that forwards
///    a raw request to `SimDevice.sendAccessibilityRequestAsync:`.
/// 2. `…ConvertPlatformFrameToSystem:withToken:` — identity (no-op).
/// 3. `…RootParentWithToken:` — always `nil`.
///
/// `@objc dynamic` and `NSObject` are required: AXP dispatches
/// these via the Objective-C runtime.
final class BridgeRelay: NSObject, @unchecked Sendable {
    private let lock = NSLock()
    private var deviceForToken: [String: NSObject] = [:]
    private var deadlineForToken: [String: Date] = [:]

    /// Associates a device with a session token. Call in a matching
    /// `defer { unregister(token:) }` pair.
    func register(device: NSObject, token: String, deadline: Date) {
        lock.lock(); defer { lock.unlock() }
        deviceForToken[token] = device
        deadlineForToken[token] = deadline
    }

    /// Removes the token → device association.
    func unregister(token: String) {
        lock.lock(); defer { lock.unlock() }
        deviceForToken.removeValue(forKey: token)
        deadlineForToken.removeValue(forKey: token)
    }

    private func lookup(token: String) -> (NSObject, Date)? {
        lock.lock(); defer { lock.unlock() }
        guard let dev = deviceForToken[token] else { return nil }
        return (dev, deadlineForToken[token] ?? .distantFuture)
    }

    // MARK: Delegate callbacks

    /// Returns a block that synchronously forwards one accessibility
    /// request to the simulator via XPC. The translator invokes this
    /// hot during element walks — every attribute read triggers a call.
    @objc dynamic
    func accessibilityTranslationDelegateBridgeCallbackWithToken(
        _ token: NSString
    ) -> Any {
        let entry = lookup(token: token as String)
        let block: @convention(block) (AnyObject) -> AnyObject = {
            [weak self] request in
            guard let self else { return BridgeRelay.emptyResponse() }
            guard let (device, deadline) = entry else {
                return BridgeRelay.emptyResponse()
            }
            let remaining = max(0, deadline.timeIntervalSinceNow)
            if remaining <= 0 { return BridgeRelay.emptyResponse() }
            return self.forwardRequest(
                request, to: device,
                timeout: min(remaining, 10.0)
            ) ?? BridgeRelay.emptyResponse()
        }
        return block
    }

    /// Identity — simulator coordinates already match host space
    /// for our purposes.
    @objc dynamic
    func accessibilityTranslationConvertPlatformFrameToSystem(
        _ rect: CGRect, withToken token: NSString
    ) -> CGRect { rect }

    /// No root parent — we only walk downward.
    @objc dynamic
    func accessibilityTranslationRootParentWithToken(
        _ token: NSString
    ) -> AnyObject? { nil }

    // MARK: XPC forwarding

    /// Synchronous wrapper around
    /// `SimDevice.sendAccessibilityRequestAsync:completionQueue:
    /// completionHandler:`. Blocks up to `timeout` seconds.
    private func forwardRequest(
        _ request: AnyObject, to device: NSObject,
        timeout: Double
    ) -> AnyObject? {
        let sel = NSSelectorFromString(
            "sendAccessibilityRequestAsync:"
            + "completionQueue:completionHandler:"
        )
        guard let imp = class_getMethodImplementation(
            type(of: device), sel
        ) else { return nil }
        typealias Fn = @convention(c) (
            AnyObject, Selector, AnyObject, DispatchQueue, Any
        ) -> Void
        let send = unsafeBitCast(imp, to: Fn.self)
        let group = DispatchGroup()
        group.enter()
        let queue = DispatchQueue(label: "simpod.ax.xpc")
        // Sendable box for the async response capture.
        final class Box: @unchecked Sendable { var value: AnyObject? }
        let box = Box()
        let completion: @convention(block) (AnyObject?) -> Void = { resp in
            box.value = resp
            group.leave()
        }
        send(device, sel, request, queue, completion as Any)
        if group.wait(timeout: .now() + timeout) == .timedOut {
            return nil
        }
        return box.value
    }

    /// Typed empty response from the AXP framework, preferred
    /// over `NSNull` because the translator may re-issue on null.
    static func emptyResponse() -> AnyObject {
        if let cls = NSClassFromString("AXPTranslatorResponse") {
            let sel = NSSelectorFromString("emptyResponse")
            if let metaCls = object_getClass(cls),
               let imp = class_getMethodImplementation(metaCls, sel) {
                typealias Fn = @convention(c) (
                    AnyClass, Selector
                ) -> AnyObject?
                if let resp = unsafeBitCast(
                    imp, to: Fn.self
                )(cls, sel) {
                    return resp
                }
            }
        }
        return NSNull()
    }
}
