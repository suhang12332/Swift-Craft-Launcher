import Foundation

struct SkinLibraryItem: Codable, Equatable, Identifiable {
    let originalFileName: String
    let sha1: String
    let model: PlayerSkinService.PublicSkinInfo.SkinModel
    let lastUsedAt: Date

    var id: String { sha1 }

    var fileURL: URL {
        AppPaths.skinsDirectory.appendingPathComponent("\(sha1).png")
    }

    var displayName: String {
        let trimmed = originalFileName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "\(sha1).png" : trimmed
    }
}
