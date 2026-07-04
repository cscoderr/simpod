//
//  SimulatorHelper.swift
//  SimpodHelper
//
//  Created by Tomiwa Idowu on 6/11/26.
//
//  Single source of truth for CoreSimulator runtime lookup: developer
//  directory, framework dlopen, service context, device set, and
//  UDID matching. Both SimulatorAccessibilityBridge and the streaming
//  path go through here so the IMP-cast plumbing only lives in one place.
//

import Foundation
import ObjectiveC

enum SimulatorHelper {

    // MARK: - Developer directory

    /// The active Xcode developer directory, resolved once via
    /// `xcode-select -p`. Falls back to the standard install path
    /// so callers don't crash on systems without xcode-select on PATH.
    static let developerDir: String = {
        let pipe = Pipe()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcode-select")
        process.arguments = ["-p"]
        process.standardOutput = pipe
        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let path = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
               !path.isEmpty
            {
                return path
            }
        } catch {}
        return "/Applications/Xcode.app/Contents/Developer"
    }()

    // MARK: - Public lookups

    /// Locates a booted `SimDevice` by UDID. Loads CoreSimulator and
    /// SimulatorKit on first call (idempotent thanks to dlopen caching).
    static func findSimDevice(with udid: String) -> NSObject? {
        guard frameworksLoaded else { return nil }
        guard let set = deviceSet() else { return nil }
        for device in allDevices(in: set) where matchesUDID(device, udid: udid) {
            return device
        }
        return nil
    }

    // MARK: - Framework loading

    /// CoreSimulator is required. SimulatorKit is best-effort —
    /// it's loaded for the HID injector path but its absence shouldn't
    /// block plain device enumeration.
    static let frameworksLoaded: Bool = {
        guard dlopen(
            "/Library/Developer/PrivateFrameworks/CoreSimulator.framework/CoreSimulator",
            RTLD_NOW | RTLD_GLOBAL
        ) != nil else { return false }
        // SimulatorKit lives under the active Xcode, not /Library.
        let simKit = (developerDir as NSString)
            .appendingPathComponent("Library/PrivateFrameworks/SimulatorKit.framework/SimulatorKit")
        _ = dlopen(simKit, RTLD_NOW | RTLD_GLOBAL)
        return true
    }()

    // MARK: - Service context / device set

    private static func deviceSet() -> NSObject? {
        guard let context = sharedServiceContext() else { return nil }
        return defaultDeviceSet(from: context)
    }

    private static func sharedServiceContext() -> NSObject? {
        guard let serviceClass = NSClassFromString("SimServiceContext") else {
            return nil
        }
        let selector = NSSelectorFromString("sharedServiceContextForDeveloperDir:error:")
        guard let metaClass = object_getClass(serviceClass),
              let imp = class_getMethodImplementation(metaClass, selector)
        else { return nil }

        typealias Fn = @convention(c) (
            AnyClass, Selector, NSString,
            AutoreleasingUnsafeMutablePointer<NSError?>
        ) -> AnyObject?
        var error: NSError?
        let result = unsafeBitCast(imp, to: Fn.self)(
            serviceClass, selector, developerDir as NSString, &error
        ) as? NSObject
        if result == nil, let error {
            print("[SimulatorHelper] sharedServiceContext: \(error.localizedDescription)")
        }
        return result
    }

    private static func defaultDeviceSet(from context: NSObject) -> NSObject? {
        let selector = NSSelectorFromString("defaultDeviceSetWithError:")
        guard let imp = class_getMethodImplementation(
            object_getClass(context), selector
        ) else { return nil }

        typealias Fn = @convention(c) (
            AnyObject, Selector,
            AutoreleasingUnsafeMutablePointer<NSError?>
        ) -> AnyObject?
        var error: NSError?
        return unsafeBitCast(imp, to: Fn.self)(
            context, selector, &error
        ) as? NSObject
    }

    private static func allDevices(in set: NSObject) -> [NSObject] {
        (set.value(forKey: "devices") as? [NSObject]) ?? []
    }

    // MARK: - UDID matching

    /// Compares the device's UDID against `udid`. Tolerates both
    /// `UUID` (Swift) and `NSUUID` (Objective-C) — different Xcode
    /// versions expose one or the other through KVC.
    private static func matchesUDID(_ device: NSObject, udid: String) -> Bool {
        if let u = device.value(forKey: "UDID") as? UUID {
            return u.uuidString == udid
        }
        if let u = device.value(forKey: "UDID") as? NSUUID {
            return u.uuidString == udid
        }
        return false
    }
}
