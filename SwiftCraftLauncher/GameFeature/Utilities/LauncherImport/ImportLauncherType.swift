//
//  ImportLauncherType.swift
//  SwiftCraftLauncher
//
//

import Foundation

/// 支持的启动器类型
enum ImportLauncherType: String, CaseIterable, Sendable {
    case all = "all"
    case officialLauncher = "Official Launcher"
    case multiMC = "MultiMC"
    case prismLauncher = "Prism Launcher"
    case gdLauncher = "GDLauncher"
    case hmcl = "HMCL"
    case sjmcLauncher = "SJMCL"
    case xmcl = "XMCL"
    case atLauncher = "ATLauncher"
    case modrinthApp = "Modrinth App"
    case curseForgeApp = "CurseForge App"

    var displayName: String {
        localizationKey.localized()
    }

    var localizationKey: String {
        switch self {
        case .all:
            return "launcher.import.launcher.all"
        case .officialLauncher:
            return "launcher.import.launcher.official"
        case .multiMC:
            return "launcher.import.launcher.multimc"
        case .prismLauncher:
            return "launcher.import.launcher.prism"
        case .gdLauncher:
            return "launcher.import.launcher.gdlauncher"
        case .hmcl:
            return "launcher.import.launcher.hmcl"
        case .sjmcLauncher:
            return "launcher.import.launcher.sjmcl"
        case .xmcl:
            return "launcher.import.launcher.xmcl"
        case .atLauncher:
            return "launcher.import.launcher.atlauncher"
        case .modrinthApp:
            return "launcher.import.launcher.modrinth"
        case .curseForgeApp:
            return "launcher.import.launcher.curseforge"
        }
    }
}
