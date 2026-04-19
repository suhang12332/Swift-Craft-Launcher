import Foundation

enum ModPackExportFormat: String, CaseIterable, Codable {
    case modrinth
    case curseforge

    var displayName: String {
        switch self {
        case .modrinth:
            return "Modrinth (.mrpack)"
        case .curseforge:
            return "CurseForge (.zip)"
        }
    }

    var fileExtension: String {
        switch self {
        case .modrinth:
            return AppConstants.FileExtensions.mrpack
        case .curseforge:
            return AppConstants.FileExtensions.zip
        }
    }
}
