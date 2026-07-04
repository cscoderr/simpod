//
//  Models.swift
//  SimpodHelper
//
//  Created by Tomiwa Idowu on 6/2/26.
//

import Foundation

enum WebSocketMessageType: String {
    case touch, pinch, button, orientation, key
}

struct TouchEventPayload: Codable {
    let phase: String   // "begin", "move", "end"
    let x: Double      // normalized 0..1
    let y: Double      // normalized 0..1
    let edge: UInt32?  // IndigoHIDEdge value (0=none, 3=bottom, etc.) — omit for regular touches
}

struct ButtonEventPayload: Codable {
    let button: String  // "home"
}

struct MultiTouchEventPayload: Codable {
    let phase: String    // "begin", "move", "end"
    let x1: Double      // finger 1 normalized 0..1
    let y1: Double
    let x2: Double      // finger 2 normalized 0..1
    let y2: Double
}

struct KeyEventPayload: Codable {
    let event: String    // "down", "up"
    let usage: UInt32   // USB HID Usage Page 0x07 keyboard code
}

struct OrientationEventPayload: Codable {
    // "portrait", "portrait_upside_down", "landscape_left", "landscape_right"
    let orientation: UInt32
}
