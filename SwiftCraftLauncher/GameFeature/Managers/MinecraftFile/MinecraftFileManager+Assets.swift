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
        let destinationURL = AppPaths.metaDirectory.appendingPathComponent(
            "assets/indexes",
        )
        .appendingPathComponent("\(manifest.assetIndex.id).json")

        do {
            _ = try await DownloadManager.downloadFile(
                urlString: manifest.assetIndex.url.absoluteString,
                destinationURL: destinationURL,
                expectedSha1: manifest.assetIndex.sha1,
            )
            let data = try Data(contentsOf: destinationURL)
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
            if let globalError = error as? GlobalError {
                throw globalError
            } else {
                throw GlobalError.download(
                    i18nKey: "error.download.asset_index_failed",
                    level: .notification,
                    message: "Failed to download asset index for manifestId=\(manifest.id), url=\(manifest.assetIndex.url.absoluteString): \(error.localizedDescription)",
                )
            }
        }
    }

    private func downloadAllAssets(
        assetIndex: DownloadedAssetIndex,
    ) async throws {
        let objectsDirectory = AppPaths.metaDirectory.appendingPathComponent(
            "assets/objects",
        )
        let assets = Array(assetIndex.objects)

        let semaphore = AsyncSemaphore(
            value: DIContainer.shared.ui.generalSettingsManager.concurrentDownloads,
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
                            objectsDirectory: objectsDirectory,
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

        do {
            let urlString = URLConfig.API.MinecraftResources.asset(hashPrefix: hashPrefix, hash: asset.hash).absoluteString
            _ = try await DownloadManager.downloadFile(
                urlString: urlString,
                destinationURL: destinationURL,
                expectedSha1: asset.hash,
            )
            let fileName = path.components(separatedBy: "/").last ?? path
            incrementCompletedFilesCount(
                fileName: fileName,
                type: .resources,
            )
        } catch {
            if let globalError = error as? GlobalError {
                throw globalError
            } else {
                throw GlobalError.download(
                    i18nKey: "error.download.asset_file_failed",
                    level: .notification,
                    message: "Failed to download asset hash=\(asset.hash), path=\(path): \(error.localizedDescription)",
                )
            }
        }
    }
}
