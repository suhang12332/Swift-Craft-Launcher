import Foundation

extension ModScanner {
    // MARK: - Fallback Methods

    /// 兜底 ModrinthProjectDetail 的公共字段结构体
    private struct CommonFallbackFields {
        let description: String
        let categories: [String]
        let clientSide: String
        let serverSide: String
        let body: String
        let additionalCategories: [String]?
        let issuesUrl: String?
        let sourceUrl: String?
        let wikiUrl: String?
        let discordUrl: String?
        let projectType: String
        let downloads: Int
        let iconUrl: String?
        let team: String
        let published: Date
        let updated: Date
        let followers: Int
        let license: License?
        let gameVersions: [String]
        let loaders: [String]
        let type: String?
    }

    /// 创建基础 ModrinthProjectDetail 的公共字段
    private func createBaseFallbackDetail(fileURL: URL) -> (fileName: String, baseFileName: String) {
        let fileName = fileURL.lastPathComponent
        let baseFileName = fileName.replacingOccurrences(
            of: ".\(fileURL.pathExtension)",
            with: ""
        )
        return (fileName, baseFileName)
    }

    /// 创建兜底 ModrinthProjectDetail 的公共部分
    private func createCommonFallbackFields(fileName: String, baseFileName: String) -> CommonFallbackFields {
        return CommonFallbackFields(
            description: "local：\(fileName)",
            categories: ["unknown"],
            clientSide: "optional",
            serverSide: "optional",
            body: "",
            additionalCategories: nil,
            issuesUrl: nil,
            sourceUrl: nil,
            wikiUrl: nil,
            discordUrl: nil,
            projectType: ResourceType.mod.rawValue,
            downloads: 0,
            iconUrl: nil,
            team: "local",
            published: Date(),
            updated: Date(),
            followers: 0,
            license: nil,
            gameVersions: [],
            loaders: [],
            type: nil
        )
    }

    /// 使用文件名创建最基础的兜底 ModrinthProjectDetail
    func createFallbackDetailFromFileName(
        fileURL: URL
    ) -> ModrinthProjectDetail {
        let (fileName, baseFileName) = createBaseFallbackDetail(fileURL: fileURL)
        let common = createCommonFallbackFields(fileName: fileName, baseFileName: baseFileName)

        return ModrinthProjectDetail(
            slug: baseFileName.lowercased().replacingOccurrences(
                of: " ",
                with: "-"
            ),
            title: baseFileName,
            description: common.description,
            categories: common.categories,
            clientSide: common.clientSide,
            serverSide: common.serverSide,
            body: common.body,
            additionalCategories: common.additionalCategories,
            issuesUrl: common.issuesUrl,
            sourceUrl: common.sourceUrl,
            wikiUrl: common.wikiUrl,
            discordUrl: common.discordUrl,
            projectType: common.projectType,
            downloads: common.downloads,
            iconUrl: common.iconUrl,
            id: "file_\(baseFileName)_\(UUID().uuidString.prefix(8))",
            team: common.team,
            published: common.published,
            updated: common.updated,
            followers: common.followers,
            license: common.license,
            versions: ["unknown"],
            gameVersions: common.gameVersions,
            loaders: common.loaders,
            type: common.type,
            fileName: fileName
        )
    }
}
