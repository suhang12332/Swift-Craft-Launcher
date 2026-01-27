import Foundation

enum CurseForgeToModrinthAdapter {
    /// 将 CurseForge 项目详情转换为 Modrinth 格式
    /// - Parameters:
    ///   - cf: CurseForge 项目详情
    ///   - description: 从 description 接口获取的 HTML 描述内容（可选，如果提供则优先使用）
    /// - Returns: Modrinth 格式的项目详情
    static func convert(_ cf: CurseForgeModDetail, description: String = "") -> ModrinthProjectDetail? {
        // 日期解析器
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        // 解析日期
        var publishedDate = Date()
        var updatedDate = Date()
        if let dateCreated = cf.dateCreated {
            publishedDate = dateFormatter.date(from: dateCreated) ?? Date()
        }
        if let dateModified = cf.dateModified {
            updatedDate = dateFormatter.date(from: dateModified) ?? Date()
        }

        // 提取游戏版本（从 latestFilesIndexes）
        var gameVersions: [String] = []
        var allVersionsFromIndexes: [String] = []
        if let indexes = cf.latestFilesIndexes {
            allVersionsFromIndexes = Array(Set(indexes.map { $0.gameVersion }))
            gameVersions = CommonUtil.sortMinecraftVersions(allVersionsFromIndexes)
        }

        // 提取加载器（从 latestFilesIndexes）
        var loaders: [String] = []
        if let indexes = cf.latestFilesIndexes {
            let loaderTypes = Set(indexes.compactMap { $0.modLoader })
            for loaderType in loaderTypes {
                if let loader = CurseForgeModLoaderType(rawValue: loaderType) {
                    switch loader {
                    case .forge:
                        loaders.append("forge")
                    case .fabric:
                        loaders.append("fabric")
                    case .quilt:
                        loaders.append("quilt")
                    case .neoforge:
                        loaders.append("neoforge")
                    }
                }
            }
        }

        // 根据项目类型处理加载器
        let projectType = cf.projectType
        if loaders.isEmpty {
            if projectType == "resourcepack" {
                // 资源包使用 "minecraft" loader
                loaders = ["minecraft"]
            } else if projectType == "datapack" {
                // 数据包使用 "datapack" loader
                loaders = ["datapack"]
            }
        }

        // 提取版本 ID 列表
        var versions: [String] = []
        if let files = cf.latestFiles {
            versions = files.map { String($0.id) }
        }

        // 提取分类
        let categories = cf.categories.map { $0.slug }

        // 提取图标 URL
        let iconUrl = cf.logo?.url ?? cf.logo?.thumbnailUrl

        // 创建许可证（CurseForge 通常没有明确的许可证信息）
        let license = License(id: "unknown", name: "Unknown", url: nil)

        // 使用 "cf-" 前缀标识 CurseForge 项目，避免与 Modrinth 项目混淆
        // 使用 description 接口返回的 HTML 内容作为 body，同时提取纯文本作为 description
        // 如果 description 为空，则回退到 summary
        let bodyContent = description.isEmpty ? (cf.body ?? cf.summary) : description
        let descriptionText = description.isEmpty ? cf.summary : extractPlainText(from: description)

        return ModrinthProjectDetail(
            slug: cf.slug ?? "curseforge-\(cf.id)",
            title: cf.name,
            description: descriptionText,
            categories: categories,
            clientSide: "optional", // CurseForge 没有明确的客户端/服务端信息
            serverSide: "optional",
            body: bodyContent,
            additionalCategories: nil,
            issuesUrl: cf.links?.issuesUrl,
            sourceUrl: cf.links?.sourceUrl,
            wikiUrl: cf.links?.wikiUrl ?? cf.links?.websiteUrl,
            discordUrl: nil, // CurseForge 没有 Discord URL
            projectType: cf.projectType,
            downloads: cf.downloadCount ?? 0,
            iconUrl: iconUrl,
            id: "cf-\(cf.id)", // 使用 "cf-" 前缀标识
            team: "",
            published: publishedDate,
            updated: updatedDate,
            followers: 0, // CurseForge 没有关注数
            license: license,
            versions: versions,
            gameVersions: gameVersions,
            loaders: loaders,
            type: cf.projectType,
            fileName: nil
        )
    }

    /// 将 CurseForge 文件详情转换为 Modrinth 版本格式
    /// - Parameters:
    ///   - cfFile: CurseForge 文件详情
    ///   - projectId: 项目 ID
    /// - Returns: Modrinth 格式的版本详情
    static func convertVersion(_ cfFile: CurseForgeModFileDetail, projectId: String) -> ModrinthProjectDetailVersion? {
        // 日期解析器
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        // 解析发布日期
        var publishedDate = Date()
        if !cfFile.fileDate.isEmpty {
            publishedDate = dateFormatter.date(from: cfFile.fileDate) ?? Date()
        }

        // 版本类型统一视为 release，避免不必要的区分
        let versionType = "release"

        // 文件级别不推断加载器，保持空数组
        let loaders: [String] = []

        // 转换依赖
        var dependencies: [ModrinthVersionDependency] = []
        if let cfDeps = cfFile.dependencies {
            dependencies = cfDeps.compactMap { dep in
                // relationType: 1 = EmbeddedLibrary, 2 = OptionalDependency, 3 = RequiredDependency, 4 = Tool, 5 = Incompatible
                let dependencyType: String
                switch dep.relationType {
                case 3: // RequiredDependency
                    dependencyType = "required"
                case 2: // OptionalDependency
                    dependencyType = "optional"
                case 5: // Incompatible
                    dependencyType = "incompatible"
                default:
                    dependencyType = "optional"
                }

                return ModrinthVersionDependency(
                    projectId: String(dep.modId),
                    versionId: nil,
                    dependencyType: dependencyType
                )
            }
        }

        // 转换文件
        let downloadUrl = cfFile.downloadUrl ?? URLConfig.API.CurseForge.fallbackDownloadUrl(
            fileId: cfFile.id,
            fileName: cfFile.fileName
        ).absoluteString

        var files: [ModrinthVersionFile] = []
        // 提取哈希值：优先使用 hashes 数组，如果没有则使用 hash 字段
        let hashes: ModrinthVersionFileHashes
        if let hashesArray = cfFile.hashes, !hashesArray.isEmpty {
            // 优先从 hashes 数组中提取
            let sha1Hash = hashesArray.first { $0.algo == 1 }
            let sha512Hash = hashesArray.first { $0.algo == 2 }
            hashes = ModrinthVersionFileHashes(
                sha512: sha512Hash?.value ?? "",
                sha1: sha1Hash?.value ?? ""
            )
        } else if let hash = cfFile.hash {
            // 如果没有 hashes 数组，使用 hash 字段
            switch hash.algo {
            case 1:
                hashes = ModrinthVersionFileHashes(sha512: "", sha1: hash.value)
            case 2:
                hashes = ModrinthVersionFileHashes(sha512: hash.value, sha1: "")
            default:
                hashes = ModrinthVersionFileHashes(sha512: "", sha1: "")
            }
        } else {
            // 如果都没有，使用空的 hash
            hashes = ModrinthVersionFileHashes(sha512: "", sha1: "")
        }

        files.append(
            ModrinthVersionFile(
                hashes: hashes,
                url: downloadUrl,
                filename: cfFile.fileName,
                primary: true, // CurseForge 通常只有一个主要文件
                size: cfFile.fileLength ?? 0,
                fileType: nil
            )
        )

        // 确保 projectId 使用 "cf-" 前缀（如果还没有）
        let normalizedProjectId = projectId.hasPrefix("cf-") ? projectId : "cf-\(projectId.replacingOccurrences(of: "cf-", with: ""))"

        return ModrinthProjectDetailVersion(
            gameVersions: cfFile.gameVersions,
            loaders: loaders,
            id: "cf-\(cfFile.id)", // 使用 "cf-" 前缀标识
            projectId: normalizedProjectId,
            authorId: cfFile.authors?.first?.name ?? "unknown",
            featured: false,
            name: cfFile.displayName,
            versionNumber: cfFile.displayName,
            changelog: cfFile.changelog,
            changelogUrl: nil,
            datePublished: publishedDate,
            downloads: 0, // CurseForge 文件没有单独的下载数
            versionType: versionType,
            status: "listed",
            requestedStatus: nil,
            files: files,
            dependencies: dependencies
        )
    }

    /// 将 CurseForge 搜索结果转换为 Modrinth 格式
    /// - Parameter cfResult: CurseForge 搜索结果
    /// - Returns: Modrinth 格式的搜索结果
    static func convertSearchResult(_ cfResult: CurseForgeSearchResult) -> ModrinthResult {
        let hits = cfResult.data.compactMap { cfMod -> ModrinthProject? in
            // 确定项目类型
            let projectType: String
            if let classId = cfMod.classId {
                switch classId {
                case 6: projectType = "mod"
                case 12: projectType = "resourcepack"
                case 6552: projectType = "shader"
                case 6945: projectType = "datapack"
                case 4471: projectType = "modpack"   // CurseForge 整合包
                default: projectType = "mod"
                }
            } else {
                projectType = "mod"
            }

            // 提取版本 ID 列表
            var versions: [String] = []
            if let files = cfMod.latestFiles {
                versions = files.map { String($0.id) }
            }

            // 使用 "cf-" 前缀标识 CurseForge 项目，避免与 Modrinth 项目混淆
            return ModrinthProject(
                projectId: "cf-\(cfMod.id)",
                projectType: projectType,
                slug: cfMod.slug ?? "curseforge-\(cfMod.id)",
                author: cfMod.authors?.first?.name ?? "Unknown",
                title: cfMod.name,
                description: cfMod.summary,
                categories: cfMod.categories?.map { $0.slug } ?? [],
                displayCategories: [],
                versions: versions,
                downloads: cfMod.downloadCount ?? 0,
                follows: 0,
                iconUrl: cfMod.logo?.url ?? cfMod.logo?.thumbnailUrl,
                license: "",
                clientSide: "optional",
                serverSide: "optional",
                fileName: nil
            )
        }

        let pagination = cfResult.pagination
        let offset = pagination?.index ?? 0
        let limit = pagination?.pageSize ?? 20
        let totalHits = pagination?.totalCount ?? hits.count

        return ModrinthResult(
            hits: hits,
            offset: offset,
            limit: limit,
            totalHits: totalHits
        )
    }

    /// 从 HTML 内容中提取纯文本作为简短描述
    /// - Parameter html: HTML 字符串
    /// - Returns: 提取的纯文本（限制长度）
    private static func extractPlainText(from html: String) -> String {
        // 简单的 HTML 标签移除，提取前 200 个字符作为描述
        let text = html
            .replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // 限制长度，避免描述过长
        if text.count > 200 {
            return String(text.prefix(200)) + "..."
        }
        return text.isEmpty ? "" : text
    }
}
