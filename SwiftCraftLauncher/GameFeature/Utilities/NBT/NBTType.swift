//
//  NBTType.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// NBT tag type identifiers used in Minecraft's Named Binary Tag format.
enum NBTType: UInt8 {
    case end = 0
    case byte = 1
    case short = 2
    case int = 3
    case long = 4
    case float = 5
    case double = 6
    case byteArray = 7
    case string = 8
    case list = 9
    case compound = 10
    case intArray = 11
    case longArray = 12
}
