import Foundation
import SwiftUI
import SkinRenderKit

extension SkinToolDetailViewModel {
    /// 加载当前激活的披风（如果存在）
    func loadCurrentActiveCapeIfNeeded(from profile: MinecraftProfileResponse,
                                       resolvedPlayer: Player?) async {
        do {
            try Task.checkCancellation()

            // 如果用户已经手动选择了与当前激活披风不同的披风，则不再加载「当前激活披风」以免覆盖预览
            if let manualSelectedId = selectedCapeId,
               let activeId = PlayerSkinService.getActiveCapeId(from: profile),
               manualSelectedId != activeId {
                return
            }

            // 优先检查 publicSkinInfo 中的 capeURL
            if let capeURL = publicSkinInfo?.capeURL, !capeURL.isEmpty {
                selectedCapeImageURL = capeURL
                isCapeLoading = true
                capeLoadCompleted = false
                try Task.checkCancellation()
                await downloadCapeTextureAndSetImage(from: capeURL, resolvedPlayer: resolvedPlayer)
                try Task.checkCancellation()
                isCapeLoading = false
                capeLoadCompleted = true
                return
            }

            try Task.checkCancellation()

            // 否则从 profile 中查找激活的披风
            guard let activeCapeId = PlayerSkinService.getActiveCapeId(from: profile) else {
                selectedCapeImageURL = nil
                selectedCapeLocalPath = nil
                selectedCapeImage = nil
                isCapeLoading = false
                capeLoadCompleted = true  // 没有披风，可以立即渲染皮肤
                return
            }

            try Task.checkCancellation()

            guard let capes = profile.capes, !capes.isEmpty else {
                selectedCapeImageURL = nil
                selectedCapeLocalPath = nil
                selectedCapeImage = nil
                isCapeLoading = false
                capeLoadCompleted = true  // 没有披风，可以立即渲染皮肤
                return
            }

            try Task.checkCancellation()

            guard let activeCape = capes.first(where: { $0.id == activeCapeId && $0.state == "ACTIVE" }) else {
                selectedCapeImageURL = nil
                selectedCapeLocalPath = nil
                selectedCapeImage = nil
                isCapeLoading = false
                capeLoadCompleted = true  // 没有激活的披风，可以立即渲染皮肤
                return
            }

            try Task.checkCancellation()

            // 有披风需要加载，设置加载状态
            selectedCapeImageURL = activeCape.url
            isCapeLoading = true
            capeLoadCompleted = false
            try Task.checkCancellation()
            await downloadCapeTextureAndSetImage(from: activeCape.url, resolvedPlayer: resolvedPlayer)
            try Task.checkCancellation()
            isCapeLoading = false
            capeLoadCompleted = true
        } catch is CancellationError {
            // 任务被取消，重置状态
            isCapeLoading = false
            capeLoadCompleted = false
        } catch {
            // 其他错误，重置状态并记录日志
            Logger.shared.error("Failed to load current active cape: \(error)")
            isCapeLoading = false
            capeLoadCompleted = false
        }
    }

    func downloadCapeTextureIfNeeded(from urlString: String) async {
        if let current = selectedCapeImageURL, current == urlString, selectedCapeLocalPath != nil {
            return
        }
        // 验证 URL 格式（但不保留 URL 对象，节省内存）
        guard URL(string: urlString.httpToHttps()) != nil else {
            return
        }
        do {
            // 使用 DownloadManager 下载文件（已包含所有优化）
            let tempFile = FileManager.default.temporaryDirectory.appendingPathComponent("cape_\(UUID().uuidString).png")
            _ = try await DownloadManager.downloadFile(
                urlString: urlString.httpToHttps(),
                destinationURL: tempFile,
                expectedSha1: nil
            )
            if selectedCapeImageURL == urlString {
                selectedCapeLocalPath = tempFile.path
            }
        } catch {
            Logger.shared.error("Cape download error: \(error)")
        }
    }

    /// 下载披风纹理并设置图片
    func downloadCapeTextureAndSetImage(from urlString: String,
                                        resolvedPlayer: Player?) async {
        // 检查是否已经下载过相同的URL
        if let currentURL = selectedCapeImageURL,
           currentURL == urlString,
           let currentPath = selectedCapeLocalPath,
           FileManager.default.fileExists(atPath: currentPath),
           let cachedImage = NSImage(contentsOfFile: currentPath) {
            try? Task.checkCancellation()
            selectedCapeImage = cachedImage
            return
        }

        // 验证 URL 格式
        guard let url = URL(string: urlString.httpToHttps()) else {
            selectedCapeImage = nil
            return
        }

        do {
            let p = playerWithCredentialIfNeeded(resolvedPlayer)
            var headers: [String: String]?
            if let t = p?.authAccessToken, !t.isEmpty {
                headers = ["Authorization": "Bearer \(t)"]
            } else {
                headers = nil
            }
            let data = try await APIClient.get(url: url, headers: headers)
            try Task.checkCancellation()

            guard !data.isEmpty, let image = NSImage(data: data) else {
                selectedCapeImage = nil
                return
            }

            try Task.checkCancellation()

            // 立即更新UI，不等待文件保存
            // 检查URL是否仍然匹配（防止用户快速切换）
            if selectedCapeImageURL == urlString {
                selectedCapeImage = image
            }

            try Task.checkCancellation()

            // 异步保存到临时文件（不阻塞UI更新）
            let tempFile = FileManager.default.temporaryDirectory.appendingPathComponent("cape_\(UUID().uuidString).png")
            do {
                try data.write(to: tempFile)
                try Task.checkCancellation()
                if selectedCapeImageURL == urlString {
                    selectedCapeLocalPath = tempFile.path
                }
            } catch is CancellationError {
                // 如果任务被取消，删除刚创建的文件
                try? FileManager.default.removeItem(at: tempFile)
            } catch {
                Logger.shared.error("Failed to save cape to temp file: \(error)")
            }
        } catch is CancellationError {
            // 任务被取消，不需要处理
        } catch {
            Logger.shared.error("Cape download error: \(error.localizedDescription)")
        }
    }
}
