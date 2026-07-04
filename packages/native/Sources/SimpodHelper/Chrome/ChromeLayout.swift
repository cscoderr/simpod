//
//  ChromeLayout.swift
//  SimpodHelper
//
//  Created by Tomiwa Idowu on 6/17/26.
//

import CoreGraphics
import Foundation

/// Typed container for the CoreSimulator profile.plist + DeviceKit
/// chrome payloads. Decoded once in `ChromeRenderer.chromeInfo(...)`
/// and threaded through every layout/draw helper.
struct ChromeInfo {
    let profile: DeviceProfile
    let metadata: ChromeMetadata
    /// Filesystem path to the `.devicechrome/Contents/Resources` dir.
    let chromePath: String
    /// Filesystem path to the simulator profile's `Resources` dir
    /// (one level above the .plist itself).
    let profileResourcesPath: String
    /// Decoded `capabilities.plist` from the same directory as `profile.plist`.
    /// Modern device types store screen dimensions/scale here (under
    /// `ScreenDimensionsCapability`, `displays[]`, or `ArtworkTraits`) rather
    /// than in `profile.plist`. Absent on older profiles, hence optional.
    let capabilities: [String: Any]?
}

struct ChromeBezelImage {
    let bare: String
    let rest: String

    var asJSON: [String: Any] {
        ["bare": bare, "rest": rest]
    }
}

struct ChromeButtonLayout {
    let name: String
    let label: String
    let type: String
    let imageName: String
    let frame: CGRect
    let anchor: String
    let align: String
    let onTop: Bool
    let restImageURL: String
    let pressedImageURL: String
    let normalOffset: CGPoint
    let rolloverOffset: CGPoint
    let imageDownName: String?
    let imageDownDrawMode: String?
    let usagePage: NSNumber?
    let usage: NSNumber?

    var asJSON: [String: Any] {
        var dict: [String: Any] = [
            "name": name,
            "label": label,
            "type": type,
            "imageName": imageName,
            "x": frame.minX,
            "y": frame.minY,
            "width": frame.width,
            "height": frame.height,
            "anchor": anchor,
            "align": align,
            "onTop": onTop,
            "images": [
                "pressed": pressedImageURL,
                "rest": restImageURL,
            ],
            "normalOffset": ["x": normalOffset.x, "y": normalOffset.y],
            "rolloverOffset": ["x": rolloverOffset.x, "y": rolloverOffset.y],
        ]
        if let imageDownName { dict["imageDownName"] = imageDownName }
        if let imageDownDrawMode { dict["imageDownDrawMode"] = imageDownDrawMode }
        if let usagePage { dict["usagePage"] = usagePage }
        if let usage { dict["usage"] = usage }
        return dict
    }
}

/// Typed projection of `ChromeRenderer.profile(...)`. Internally the renderer
/// works in CGFloats; `asJSON` rebuilds the legacy dictionary shape consumed by
/// the HTTP `/chrome` endpoint so the wire format does not change.
struct ChromeLayout {
    let totalWidth: CGFloat
    let totalHeight: CGFloat
    let chromeX: CGFloat
    let chromeY: CGFloat
    let chromeWidth: CGFloat
    let chromeHeight: CGFloat
    let screenX: CGFloat
    let screenY: CGFloat
    let screenWidth: CGFloat
    let screenHeight: CGFloat
    let contentX: CGFloat
    let contentY: CGFloat
    let contentWidth: CGFloat
    let contentHeight: CGFloat
    let cornerRadius: CGFloat
    let chromeCornerRadius: CGFloat
    let hasScreenMask: Bool
    let buttons: [ChromeButtonLayout]
    let bezelImage: ChromeBezelImage

    var asJSON: [String: Any] {
        [
            "totalWidth": totalWidth,
            "totalHeight": totalHeight,
            "chromeX": chromeX,
            "chromeY": chromeY,
            "chromeWidth": chromeWidth,
            "chromeHeight": chromeHeight,
            "screenX": screenX,
            "screenY": screenY,
            "screenWidth": screenWidth,
            "screenHeight": screenHeight,
            "contentX": contentX,
            "contentY": contentY,
            "contentWidth": contentWidth,
            "contentHeight": contentHeight,
            "cornerRadius": cornerRadius,
            "chromeCornerRadius": chromeCornerRadius,
            "hasScreenMask": hasScreenMask,
            "buttons": buttons.map(\.asJSON),
            "bezelImage": bezelImage.asJSON,
        ]
    }
}
