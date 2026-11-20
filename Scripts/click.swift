#!/usr/bin/env swift
// Posts a real mouse click at a screen coordinate (Quartz global space).
// Usage: swift Scripts/click.swift <x> <y>

import CoreGraphics
import Foundation

guard CommandLine.arguments.count >= 3,
      let x = Double(CommandLine.arguments[1]),
      let y = Double(CommandLine.arguments[2]) else {
    exit(1)
}

let point = CGPoint(x: x, y: y)
let source = CGEventSource(stateID: .hidSystemState)

let move = CGEvent(mouseEventSource: source, mouseType: .mouseMoved, mouseCursorPosition: point, mouseButton: .left)
move?.post(tap: .cghidEventTap)
usleep(120_000)

let down = CGEvent(mouseEventSource: source, mouseType: .leftMouseDown, mouseCursorPosition: point, mouseButton: .left)
down?.post(tap: .cghidEventTap)
usleep(80_000)

let up = CGEvent(mouseEventSource: source, mouseType: .leftMouseUp, mouseCursorPosition: point, mouseButton: .left)
up?.post(tap: .cghidEventTap)

print("clicked \(Int(x)),\(Int(y))")
