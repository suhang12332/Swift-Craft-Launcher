//
//  CurseForgeModels+AppExtensions.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

extension CurseForgeClassId {
    /// The filesystem directory name corresponding to this content type.
    var directoryName: String {
        switch self {
        case .mods:
            return AppConstants.DirectoryNames.mods
        case .resourcePacks:
            return AppConstants.DirectoryNames.resourcepacks
        case .shaders:
            return AppConstants.DirectoryNames.shaderpacks
        case .datapacks:
            return AppConstants.DirectoryNames.datapacks
        case .modpacks:
            return "modpacks"
        }
    }
}

extension CurseForgeModDetail {
    /// The filesystem directory name derived from the content type.
    var directoryName: String {
        contentType?.directoryName ?? AppConstants.DirectoryNames.mods
    }

    /// The project type string (mod, resourcepack, shader, datapack, or modpack).
    var projectType: String {
        switch contentType {
        case .mods:
            return ResourceType.mod.rawValue
        case .resourcePacks:
            return ResourceType.resourcepack.rawValue
        case .shaders:
            return ResourceType.shader.rawValue
        case .datapacks:
            return ResourceType.datapack.rawValue
        case .modpacks:
            return ResourceType.modpack.rawValue
        default:
            return ResourceType.mod.rawValue
        }
    }
}
