import Foundation

public extension ModrinthProjectDetail {
    static func fromV3(_ v3: ModrinthProjectDetailV3) -> ModrinthProjectDetail {
        let serverInfo = v3.minecraftJavaServer
        let address = serverInfo?.address ?? ""
        let online = serverInfo?.ping?.data?.playersOnline
        let max = serverInfo?.ping?.data?.playersMax

        let fileName: String? = {
            guard !address.isEmpty else { return nil }
            if let online, let max {
                return "\(address) | \(online) | \(max)"
            } else if let online {
                return "\(address) | \(online)"
            } else {
                return address
            }
        }()

        return ModrinthProjectDetail(
            slug: v3.slug,
            title: v3.name,
            description: v3.summary,
            categories: v3.categories,
            clientSide: "required",
            serverSide: "required",
            body: v3.description,
            additionalCategories: v3.additionalCategories,
            issuesUrl: v3.linkUrls?.wiki?.url,
            sourceUrl: nil,
            wikiUrl: v3.linkUrls?.wiki?.url,
            discordUrl: v3.linkUrls?.discord?.url,
            projectType: v3.projectTypes.first ?? "minecraft_java_server",
            downloads: v3.downloads,
            iconUrl: v3.iconUrl,
            id: v3.id,
            team: v3.organization ?? "",
            published: v3.published,
            updated: v3.updated,
            followers: v3.followers,
            license: v3.license,
            versions: v3.versions,
            gameVersions: {
                let primary = v3.gameVersions
                let fallback = v3.minecraftJavaServer?.content?.supportedGameVersions ?? []

                var seen = Set<String>()
                var merged: [String] = []
                merged.reserveCapacity(primary.count + fallback.count)

                for v in primary where seen.insert(v).inserted {
                    merged.append(v)
                }
                for v in fallback where seen.insert(v).inserted {
                    merged.append(v)
                }
                return merged
            }(),
            loaders: v3.loaders,
            type: nil,
            fileName: fileName
        )
    }
}

public extension ModrinthProject {
    static func from(detail: ModrinthProjectDetail) -> ModrinthProject {
        ModrinthProject(
            projectId: detail.id,
            projectType: detail.projectType,
            slug: detail.slug,
            author: detail.team,
            title: detail.title,
            description: detail.description,
            categories: detail.categories,
            displayCategories: detail.additionalCategories ?? [],
            versions: detail.versions,
            downloads: detail.downloads,
            follows: detail.followers,
            iconUrl: detail.iconUrl,
            license: detail.license?.name ?? "",
            clientSide: detail.clientSide,
            serverSide: detail.serverSide,
            fileName: detail.fileName
        )
    }
}
