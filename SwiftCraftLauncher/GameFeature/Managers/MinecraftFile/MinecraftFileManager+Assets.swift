//
//  MinecraftFileManager+Assets.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Asset download extension for MinecraftFileManager.
extension MinecraftFileManager {
    func downloadAssets(
        manifest: MinecraftVersionManifest,
    ) async throws {
        let assetIndex = try await downloadAssetIndex(manifest: manifest)
        resourceTotalFiles = assetIndex.objects.count

        try await downloadAllAssets(assetIndex: assetIndex)
    }

    private func downloadAssetIndex(
        manifest: MinecraftVersionManifest,
    ) async throws -> DownloadedAssetIndex {
        let destinationURL = AppPaths.indexesDirectory.appendingPathComponent("\(manifest.assetIndex.id).json")

        try await downloadAndSaveFile(
            from: manifest.assetIndex.url,
            to: destinationURL,
            sha1: manifest.assetIndex.sha1,
            type: .core,
            i18nKey: "error.download.asset_index_failed",
            errorMessage: "Failed to download asset index for manifestId=\(manifest.id), url=\(manifest.assetIndex.url.absoluteString)",
        )

        let data: Data
        do {
            data = try Data(contentsOf: destinationURL)
            let assetIndexData = try JSONDecoder().decode(
                AssetIndexData.self,
                from: data,
            )
            var totalSize = 0
            for object in assetIndexData.objects.values {
                totalSize += object.size
            }
            return DownloadedAssetIndex(
                id: manifest.assetIndex.id,
                url: manifest.assetIndex.url,
                sha1: manifest.assetIndex.sha1,
                totalSize: totalSize,
                objects: assetIndexData.objects,
            )
        } catch {
            throw GlobalError.download(
                i18nKey: "error.download.asset_index_failed",
                level: .notification,
                message: "Failed to read asset index for manifestId=\(manifest.id), url=\(manifest.assetIndex.url.absoluteString): \(error.localizedDescription)",
            )
        }
    }

    private func downloadAllAssets(
        assetIndex: DownloadedAssetIndex,
    ) async throws {
        let assets = Array(assetIndex.objects)

        let semaphore = AsyncSemaphore(
            value: DIContainer.shared.ui.gameSettingsManager.concurrentDownloads,
        )

        for chunk in stride(
            from: 0,
            to: assets.count,
            by: MinecraftFileManagerConstants.assetChunkSize,
        ) {
            let end = min(chunk + MinecraftFileManagerConstants.assetChunkSize, assets.count)
            let currentChunk = assets[chunk ..< end]

            try await withThrowingTaskGroup(of: Void.self) { group in
                for (path, asset) in currentChunk {
                    group.addTask { [weak self] in
                        await semaphore.wait()
                        defer { Task { await semaphore.signal() } }

                        try await self?.downloadAsset(
                            asset: asset,
                            path: path,
                            objectsDirectory: AppPaths.objectsDirectory,
                        )
                    }
                }
                try await group.waitForAll()
            }
        }
    }

    private func downloadAsset(
        asset: AssetIndexData.AssetObject,
        path: String,
        objectsDirectory: URL,
    ) async throws {
        let hashPrefix = String(asset.hash.prefix(2))
        let assetDirectory = objectsDirectory.appendingPathComponent(hashPrefix)
        let destinationURL = assetDirectory.appendingPathComponent(asset.hash)

        let fileName = path.components(separatedBy: "/").last ?? path
        try await downloadAndSaveFile(
            from: URLConfig.API.MinecraftResources.asset(hashPrefix: hashPrefix, hash: asset.hash),
            to: destinationURL,
            sha1: asset.hash,
            fileNameForNotification: fileName,
            type: .resources,
            i18nKey: "error.download.asset_file_failed",
            errorMessage: "Failed to download asset hash=\(asset.hash), path=\(path)",
        )
    }
}
