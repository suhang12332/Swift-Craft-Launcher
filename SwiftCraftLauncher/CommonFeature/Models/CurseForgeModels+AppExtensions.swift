import Foundation

extension CurseForgeClassId {
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
            // 整合包不属于单一资源目录，这里仅提供一个占位目录名
            return "modpacks"
        }
    }
}

extension CurseForgeModDetail {
    var directoryName: String {
        contentType?.directoryName ?? AppConstants.DirectoryNames.mods
    }
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
