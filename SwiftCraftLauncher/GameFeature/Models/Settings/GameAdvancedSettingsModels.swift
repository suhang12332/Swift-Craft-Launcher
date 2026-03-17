import Foundation

enum GarbageCollector: String, CaseIterable {
    case g1gc = "g1gc"
    case zgc = "zgc"
    case shenandoah = "shenandoah"
    case parallel = "parallel"
    case serial = "serial"

    /// 垃圾回收器所需的最低 Java 版本
    var minimumJavaVersion: Int {
        switch self {
        case .g1gc: return 7       // Java 7+ (G1GC 在 Java 7u4+ 可用)
        case .parallel: return 1   // Java 1.0+ (所有版本都支持)
        case .serial: return 1     // Java 1.0+ (所有版本都支持)
        case .zgc: return 11       // Java 11+ (ZGC 在 Java 11 引入)
        case .shenandoah: return 12 // Java 12+ (Shenandoah 在 Java 12 引入)
        }
    }

    func isSupported(by javaVersion: Int) -> Bool {
        javaVersion >= minimumJavaVersion
    }

    var displayName: String {
        switch self {
        case .g1gc: return "settings.game.java.gc.g1gc".localized()
        case .zgc: return "settings.game.java.gc.zgc".localized()
        case .shenandoah: return "settings.game.java.gc.shenandoah".localized()
        case .parallel: return "settings.game.java.gc.parallel".localized()
        case .serial: return "settings.game.java.gc.serial".localized()
        }
    }

    var description: String {
        switch self {
        case .g1gc: return "settings.game.java.gc.g1gc.desc".localized()
        case .zgc: return "settings.game.java.gc.zgc.desc".localized()
        case .shenandoah: return "settings.game.java.gc.shenandoah.desc".localized()
        case .parallel: return "settings.game.java.gc.parallel.desc".localized()
        case .serial: return "settings.game.java.gc.serial.desc".localized()
        }
    }

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

enum OptimizationPreset: String, CaseIterable {
    case disabled = "disabled"
    case basic = "basic"
    case balanced = "balanced"
    case maximum = "maximum"

    var displayName: String {
        switch self {
        case .disabled: return "settings.game.java.optimization.none".localized()
        case .basic: return "settings.game.java.optimization.basic".localized()
        case .balanced: return "settings.game.java.optimization.balanced".localized()
        case .maximum: return "settings.game.java.optimization.maximum".localized()
        }
    }

    var description: String {
        switch self {
        case .disabled: return "settings.game.java.optimization.none.desc".localized()
        case .basic: return "settings.game.java.optimization.basic.desc".localized()
        case .balanced: return "settings.game.java.optimization.balanced.desc".localized()
        case .maximum: return "settings.game.java.optimization.maximum.desc".localized()
        }
    }
}

