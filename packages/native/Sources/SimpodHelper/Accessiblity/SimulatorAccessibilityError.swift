//
//  SimulatorAccessibilityError.swift
//  SimpodHelper
//
//  Created by Tomiwa Idowu on 6/9/26.
//

import Foundation

/// Errors that surface when the accessibility bridge cannot connect
/// to a simulator or retrieve its UI tree.
enum SimulatorAccessibilityError: Error, LocalizedError {
    /// `dlopen` failed — Xcode toolchain may be missing or the OS
    /// doesn't ship the private framework.
    case frameworkUnavailable
    /// The `AXPTranslator` class / shared instance couldn't be
    /// resolved — framework version mismatch.
    case translatorUnavailable
    /// No frontmost app on the simulator (not booted, or
    /// SpringBoard hasn't surfaced an app yet).
    case noFrontmostApplication
    /// An XPC round-trip exceeded the per-call deadline.
    case timeout
    /// The UDID doesn't match any booted device in CoreSimulator.
    case deviceNotFound(String)

    var errorDescription: String? {
        switch self {
        case .frameworkUnavailable:
            return "AccessibilityPlatformTranslation framework not loadable"
        case .translatorUnavailable:
            return "AXPTranslator class not found at runtime"
        case .noFrontmostApplication:
            return "No frontmost application returned for simulator"
        case .timeout:
            return "Timed out waiting for accessibility response"
        case .deviceNotFound(let udid):
            return "Simulator device not found: \(udid)"
        }
    }
}
