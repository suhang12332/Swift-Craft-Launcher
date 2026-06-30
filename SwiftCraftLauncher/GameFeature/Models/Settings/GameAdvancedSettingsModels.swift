//
//  GameAdvancedSettingsModels.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Java garbage collector options available for game configuration.
enum GarbageCollector: String, CaseIterable {
    case g1gc = "g1gc"
    case zgc = "zgc"
    case shenandoah = "shenandoah"
    case parallel = "parallel"
    case serial = "serial"

    /// The minimum Java major version required by this garbage collector.
    var minimumJavaVersion: Int {
        switch self {
        case .g1gc: return 7
        case .parallel: return 1
        case .serial: return 1
        case .zgc: return 11
        case .shenandoah: return 12
        }
    }

    /// Returns whether the given Java version supports this garbage collector.
    func isSupported(by javaVersion: Int) -> Bool {
        javaVersion >= minimumJavaVersion
    }

    /// The localized display name for this garbage collector.
    var displayName: String {
        switch self {
        case .g1gc: return "settings.game.java.gc.g1gc".localized()
        case .zgc: return "settings.game.java.gc.zgc".localized()
        case .shenandoah: return "settings.game.java.gc.shenandoah".localized()
        case .parallel: return "settings.game.java.gc.parallel".localized()
        case .serial: return "settings.game.java.gc.serial".localized()
        }
    }

    /// The localized description for this garbage collector.
    var description: String {
        switch self {
        case .g1gc: return "settings.game.java.gc.g1gc.desc".localized()
        case .zgc: return "settings.game.java.gc.zgc.desc".localized()
        case .shenandoah: return "settings.game.java.gc.shenandoah.desc".localized()
        case .parallel: return "settings.game.java.gc.parallel.desc".localized()
        case .serial: return "settings.game.java.gc.serial.desc".localized()
        }
    }

    /// The JVM arguments that enable this garbage collector.
    var arguments: [String] {
        switch self {
        case .g1gc: return ["-XX:+UseG1GC"]
        case .zgc: return ["-XX:+UseZGC"]
        case .shenandoah: return ["-XX:+UseShenandoahGC"]
        case .parallel: return ["-XX:+UseParallelGC"]
        case .serial: return ["-XX:+UseSerialGC"]
        }
    }
}

/// JVM optimization presets for game performance tuning.
enum OptimizationPreset: String, CaseIterable {
    case disabled = "disabled"
    case basic = "basic"
    case balanced = "balanced"
    case maximum = "maximum"

    /// The localized display name for this optimization preset.
    var displayName: String {
        switch self {
        case .disabled: return "settings.game.java.optimization.none".localized()
        case .basic: return "settings.game.java.optimization.basic".localized()
        case .balanced: return "settings.game.java.optimization.balanced".localized()
        case .maximum: return "settings.game.java.optimization.maximum".localized()
        }
    }

    /// The localized description for this optimization preset.
    var description: String {
        switch self {
        case .disabled: return "settings.game.java.optimization.none.desc".localized()
        case .basic: return "settings.game.java.optimization.basic.desc".localized()
        case .balanced: return "settings.game.java.optimization.balanced.desc".localized()
        case .maximum: return "settings.game.java.optimization.maximum.desc".localized()
        }
    }
}
