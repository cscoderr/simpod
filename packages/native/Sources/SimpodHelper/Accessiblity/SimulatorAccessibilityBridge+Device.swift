//
//  SimulatorAccessibilityBridge+Device.swift
//  SimpodHelper
//
//  Created by Tomiwa Idowu on 6/9/26.
//
//  AXP-specific bits of device lookup that don't belong in
//  `SimulatorHelper`. The actual CoreSimulator plumbing (developer
//  dir, dlopen, service context, device set, UDID match) lives in
//  `SimulatorHelper` — see findSimDevice(with:).
//

import CoreGraphics
import Foundation
import ObjectiveC

extension SimulatorAccessibilityBridge {

    /// Resolves the simulator's logical point-size from its
    /// `deviceType.mainScreenSize` (pixels) / `mainScreenScale`.
    /// Falls back to iPhone 15 Pro dimensions when unavailable.
    static func resolveDeviceScreenSize(for device: NSObject) -> CGSize {
        let fallback = CGSize(width: 393, height: 852)
        guard let deviceType = device.value(forKey: "deviceType") as? NSObject else {
            return fallback
        }
        let pixelSize: CGSize
        if let raw = deviceType.value(forKey: "mainScreenSize") as? CGSize {
            pixelSize = raw
        } else if let nsv = deviceType.value(forKey: "mainScreenSize") as? NSValue {
            pixelSize = nsv.sizeValue
        } else {
            return fallback
        }
        let scale = (deviceType.value(forKey: "mainScreenScale") as? NSNumber)?
            .doubleValue ?? 3.0
        guard scale > 0 else { return fallback }
        return CGSize(
            width: pixelSize.width / scale,
            height: pixelSize.height / scale
        )
    }
}
