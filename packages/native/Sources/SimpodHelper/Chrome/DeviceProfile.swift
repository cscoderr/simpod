//
//  DeviceProfile.swift
//  SimpodHelper
//
//  Created by Tomiwa Idowu on 6/17/26.
//
//  Typed view of `profile.plist` from CoreSimulator's DeviceTypes
//  bundle. We only model the keys the renderer reads — unknown keys
//  are ignored on decode so Apple is free to add fields.
//

import Foundation

/// Decoded `profile.plist` for a single device type. Every numeric
/// field is optional because older device profiles ship with smaller
/// schemas; the renderer treats absent values as zero or fallback.
struct DeviceProfile: Decodable {
    let mainScreenWidth: Double?
    let mainScreenHeight: Double?
    let mainScreenScale: Double?
    let chromeIdentifier: String?
    /// CoreSimulator stores family IDs as a mix of `NSNumber` and
    /// `String` depending on profile vintage — see [[ChromeRenderer-Profile]].
    let supportedProductFamilyIDs: [SupportedFamilyID]?
    /// Filename (without .pdf) of the iPhone notch/Dynamic-Island
    /// sensor-bar overlay, if any.
    let sensorBarImage: String?
    /// Filename (without .pdf) of the round/odd-shape screen mask.
    let framebufferMask: String?

    /// Decodes from binary or XML plist data, falling back to a
    /// loose `PropertyListDecoder` when JSONDecoder-style coercion
    /// trips on tagged numbers.
    static func decode(from data: Data) throws -> DeviceProfile {
        try PropertyListDecoder().decode(DeviceProfile.self, from: data)
    }
}

/// A family-ID entry; CoreSimulator mixes int and string forms,
/// so the decoder tolerates both.
enum SupportedFamilyID: Decodable, Equatable {
    case integer(Int)
    case string(String)

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let i = try? c.decode(Int.self) { self = .integer(i); return }
        if let s = try? c.decode(String.self) { self = .string(s); return }
        throw DecodingError.dataCorruptedError(
            in: c,
            debugDescription: "Family ID must be Int or String"
        )
    }

    /// The numeric family ID. iOS = 1, watchOS = 4.
    var intValue: Int? {
        switch self {
        case .integer(let i): return i
        case .string(let s):  return Int(s)
        }
    }
}
