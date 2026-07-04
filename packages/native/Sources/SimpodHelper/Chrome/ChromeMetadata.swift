//
//  ChromeMetadata.swift
//  SimpodHelper
//
//  Created by Tomiwa Idowu on 6/17/26.
//

import CoreGraphics
import Foundation

/// Top-level decoded `chrome.json`.
struct ChromeMetadata: Decodable {
    let images: Images?
    let paths: Paths?
    let inputs: [ChromeInput]?

    static func decode(from data: Data) throws -> ChromeMetadata {
        try JSONDecoder().decode(ChromeMetadata.self, from: data)
    }

    // MARK: - Images

    /// All the artwork references for the bezel and its accessories.
    /// `composite` / `simpleComposite` point at one big PDF; the
    /// 9-slice fields (`topLeft`, `top`, …) point at the older
    /// sliced format. Modern phones use neither — they're rendered
    /// from sliced metadata directly in code.
    struct Images: Decodable {
        let sizing: Sizing?
        let stand: Stand?
        let padding: Size?
        let devicePadding: EdgeInsets?
        let composite: String?
        let simpleComposite: String?

        // Sliced-chrome asset names. Each is the PDF filename
        // (with or without extension) under the .devicechrome bundle.
        let topLeft: String?
        let top: String?
        let topRight: String?
        let left: String?
        let right: String?
        let bottomLeft: String?
        let bottom: String?
        let bottomRight: String?
    }

    /// Edge metrics for the sliced chrome's outer border.
    struct Sizing: Decodable {
        let topHeight: Double?
        let leftWidth: Double?
        let bottomHeight: Double?
        let rightWidth: Double?
    }

    /// iPad stand: a 3-slice strip below the bezel (left cap,
    /// stretchable centre, right cap).
    struct Stand: Decodable {
        let width: Double?
        let height: Double?
        let left: String?
        let center: String?
        let right: String?
    }

    /// Width/height pair. Used for `images.padding` (watch).
    struct Size: Decodable {
        let width: Double?
        let height: Double?

        var cgSize: CGSize {
            CGSize(width: width ?? 0, height: height ?? 0)
        }
    }

    /// CSS-style edge insets. Used for borders and device padding.
    struct EdgeInsets: Decodable {
        let top: Double?
        let left: Double?
        let bottom: Double?
        let right: Double?
    }

    // MARK: - Paths

    struct Paths: Decodable {
        let simpleOutsideBorder: Border?
    }

    struct Border: Decodable {
        let insets: EdgeInsets?
        let cornerRadiusX: Double?
    }
}

// MARK: - ChromeInput

/// One physical input on the device (button, crown, volume rocker).
/// The renderer uses these for both drawing (overlay artwork) and
/// for the JSON button-layout that the UI consumes for hit-targets.
struct ChromeInput: Decodable {
    let name: String?
    let image: String?
    let imageDown: String?
    let imageDownDrawMode: String?
    let type: String?
    let anchor: String?
    let align: String?
    let accessibilityTitle: String?
    let offsets: Offsets?
    let onTop: Bool?
    let usagePage: Int?
    let usage: Int?

    struct Offsets: Decodable {
        let normal: Point?
        let rollover: Point?
    }

    struct Point: Decodable {
        let x: Double?
        let y: Double?
    }
}
