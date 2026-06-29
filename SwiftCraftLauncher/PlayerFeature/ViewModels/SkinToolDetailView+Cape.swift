import Foundation
import SwiftUI
import SkinRenderKit

extension SkinToolDetailViewModel {
    /// 加载当前激活的披风（如果存在）
    func loadCurrentActiveCapeIfNeeded(
        from profile: MinecraftProfileResponse,
        resolvedPlayer: Player?
    ) async {
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

            guard let activeCapeId = PlayerSkinService.getActiveCapeId(from: profile) else {
                selectedCapeImageURL = nil
                selectedCapeLocalPath = nil
                selectedCapeImage = nil
                isCapeLoading = false
                capeLoadCompleted = true
                return
            }

            try Task.checkCancellation()

            guard let capes = profile.capes, !capes.isEmpty else {
                selectedCapeImageURL = nil
                selectedCapeLocalPath = nil
                selectedCapeImage = nil
                isCapeLoading = false
                capeLoadCompleted = true
                return
            }

            try Task.checkCancellation()

            guard let activeCape = capes.first(where: { $0.id == activeCapeId && $0.state == "ACTIVE" }) else {
                selectedCapeImageURL = nil
                selectedCapeLocalPath = nil
                selectedCapeImage = nil
                isCapeLoading = false
                capeLoadCompleted = true
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
            isCapeLoading = false
            capeLoadCompleted = false
        } catch {
            Logger.shared.error("Failed to load current active cape: \(error)")
            isCapeLoading = false
            capeLoadCompleted = false
        }
    }

    func downloadCapeTextureIfNeeded(from urlString: String) async {
        if let current = selectedCapeImageURL, current == urlString, selectedCapeLocalPath != nil {
            return
        }
        guard URL(string: urlString.httpToHttps()) != nil else {
            return
        }
        do {
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
    func downloadCapeTextureAndSetImage(
        from urlString: String,
        resolvedPlayer: Player?
    ) async {
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
                headers = [APIClient.Header.authorization: APIClient.bearer(t)]
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

            if selectedCapeImageURL == urlString {
                selectedCapeImage = image
            }

            try Task.checkCancellation()

            let tempFile = FileManager.default.temporaryDirectory.appendingPathComponent("cape_\(UUID().uuidString).png")
            do {
                try data.write(to: tempFile)
                try Task.checkCancellation()
                if selectedCapeImageURL == urlString {
                    selectedCapeLocalPath = tempFile.path
                }
            } catch is CancellationError {
                try? FileManager.default.removeItem(at: tempFile)
            } catch {
                Logger.shared.error("Failed to save cape to temp file: \(error)")
            }
        } catch is CancellationError {
        } catch {
            Logger.shared.error("Cape download error: \(error.localizedDescription)")
        }
    }
}
