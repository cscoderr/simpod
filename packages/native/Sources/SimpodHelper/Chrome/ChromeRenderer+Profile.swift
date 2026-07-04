//
//  ChromeRenderer+Profile.swift
//  SimpodHelper
//
//  Created by Tomiwa Idowu on 6/17/26.
//
//  Tiny utilities that classify a DeviceKit profile (phone vs watch) or
//  resolve named assets on disk. Pulled out so the bigger files don't have
//  to keep these around at the bottom.
//

import Foundation

extension ChromeRenderer {

    /// True if this device is a watchOS profile. Detection looks at both the
    /// chrome identifier (`*.watch*`) and the `supportedProductFamilyIDs`
    /// array (`4` = watch), because older profiles only set one of the two.
    func isWatchProfile(_ profile: DeviceProfile?) -> Bool {
        guard let profile else { return false }
        if (profile.chromeIdentifier ?? "").contains(".watch") { return true }
        return profile.supportedProductFamilyIDs?
            .contains { $0.intValue == 4 } ?? false
    }

    /// True if this device is an iPhone profile. Same dual-path detection
    /// as watches: `*.phone*` identifier or family ID `1`.
    func isPhoneProfile(_ profile: DeviceProfile?) -> Bool {
        guard let profile else { return false }
        if (profile.chromeIdentifier ?? "").contains(".phone") { return true }
        return profile.supportedProductFamilyIDs?
            .contains { $0.intValue == 1 } ?? false
    }

    /// Resolves the path to the composite bezel PDF, or empty string if the
    /// profile is one of the modern phones that uses sliced chrome instead.
    func compositeAssetPath(for info: ChromeInfo) -> String {
        let profile = info.profile
        let sensorName = profile.sensorBarImage ?? ""
        if shouldRenderPhoneChromeFromSlices(profile, sensorName: sensorName) {
            return ""
        }

        let images = info.metadata.images
        // `simpleComposite` is the older key — supported for back-compat
        // with profiles that ship under both schemas.
        let name = images?.composite ?? images?.simpleComposite ?? ""
        if name.isEmpty { return "" }
        return resolvedChromeAssetPath(forName: name, chromePath: info.chromePath)
    }

    /// Modern iPhones (iPhone 11+) ship a sensor bar image and expect the
    /// chrome to be assembled from slices, not the legacy composite PDF.
    func shouldRenderPhoneChromeFromSlices(_ profile: DeviceProfile, sensorName: String) -> Bool {
        if !isPhoneProfile(profile) { return false }
        if !sensorName.isEmpty { return true }
        let chromeIdentifier = profile.chromeIdentifier ?? ""
        return chromeIdentifier.hasSuffix(".phone11") || chromeIdentifier.hasSuffix(".phone12") || chromeIdentifier.hasSuffix(".phone13")
    }

    // MARK: - capabilities.plist accessors

    /// Root of the device's `capabilities.plist`, unwrapping the optional
    /// nested `capabilities` sub-key some profiles use.
    func capabilities(for info: ChromeInfo) -> [String: Any]? {
        guard let root = info.capabilities else { return nil }
        return (root["capabilities"] as? [String: Any]) ?? root
    }

    /// The `ScreenDimensionsCapability` dictionary, if present.
    func screenDimensions(for info: ChromeInfo) -> [String: Any]? {
        capabilities(for: info)?["ScreenDimensionsCapability"] as? [String: Any]
    }

    /// Picks the device's primary display out of the `displays[]` array.
    /// An exact `chromeIdentifier` match wins; otherwise we prefer the
    /// display named `primary`, then the first `integrated` one, then the
    /// first entry.
    func primaryDisplay(for info: ChromeInfo) -> [String: Any]? {
        guard let caps = capabilities(for: info) else { return nil }
        let displays  = caps["displays"] as? [[String: Any]] ?? []
        let profileID = info.profile.chromeIdentifier ?? ""

        var firstDisplay:    [String: Any]? = nil
        var firstIntegrated: [String: Any]? = nil
        var firstPrimary:    [String: Any]? = nil

        for display in displays {
            if firstDisplay    == nil { firstDisplay = display }
            if firstIntegrated == nil, (display["displayType"] as? String) == "integrated" { firstIntegrated = display }
            if firstPrimary    == nil, (display["deviceName"]  as? String) == "primary"    { firstPrimary    = display }
            if !profileID.isEmpty, (display["chromeIdentifier"] as? String) == profileID   { return display }
        }
        return firstPrimary ?? firstIntegrated ?? firstDisplay
    }

    // MARK: - Display pixel size / scale (with fallback chain)

    /// The native pixel size of the device's main screen framebuffer.
    ///
    /// Cascades through four sources because no single one is populated on
    /// every device-type vintage: legacy `profile.plist` keys → the
    /// `ScreenDimensionsCapability` → the primary `displays[]` entry → the
    /// framebuffer mask PDF as a last resort.
    func displayPixelSize(for info: ChromeInfo) throws -> CGSize {
        let profile = info.profile
        var width  = CGFloat(profile.mainScreenWidth ?? 0)
        var height = CGFloat(profile.mainScreenHeight ?? 0)

        if width <= 0 || height <= 0, let dims = screenDimensions(for: info) {
            width  = numberValue(dims["main-screen-width"])
            height = numberValue(dims["main-screen-height"])
        }

        if width <= 0 || height <= 0, let display = primaryDisplay(for: info) {
            width  = numberValue(display["width"])
            height = numberValue(display["height"])
        }

        if width <= 0 || height <= 0 {
            let maskSize = framebufferMaskSize(for: info)
            width  = maskSize.width
            height = maskSize.height
        }

        guard width > 0, height > 0 else {
            throw makeError(description: "The CoreSimulator device profile did not specify a framebuffer size.", code: 16)
        }
        return CGSize(width: width, height: height)
    }

    /// The device's main screen scale factor, with the same cascading
    /// fallback as `displayPixelSize(for:)`: legacy `profile.plist` →
    /// `ScreenDimensionsCapability` → primary `displays[]` → `ArtworkTraits`.
    func screenScale(for info: ChromeInfo) -> CGFloat {
        var scale = CGFloat(info.profile.mainScreenScale ?? 0)

        if scale <= 0, let dims = screenDimensions(for: info) {
            scale = numberValue(dims["main-screen-scale"])
        }

        if scale <= 0, let display = primaryDisplay(for: info) {
            scale = numberValue(display["scale"])
        }

        if scale <= 0, let caps = capabilities(for: info),
           let traits = caps["ArtworkTraits"] as? [String: Any] {
            scale = numberValue(traits["ArtworkDeviceScaleFactor"])
        }

        return max(scale, 1.0)
    }

    /// Looks up a named PDF asset, falling back to appending `.pdf` if the
    /// name was supplied bare. Returns the input path verbatim when nothing
    /// matches — callers are expected to handle the resulting "not found".
    func resolvedChromeAssetPath(forName name: String, chromePath: String) -> String {
        let candidate = (chromePath as NSString).appendingPathComponent(name)
        if FileManager.default.fileExists(atPath: candidate) {
            return candidate
        }
        if (name as NSString).pathExtension.isEmpty {
            let pdfPath = "\(candidate).pdf"
            if FileManager.default.fileExists(atPath: pdfPath) {
                return pdfPath
            }
        }
        return candidate
    }
}
