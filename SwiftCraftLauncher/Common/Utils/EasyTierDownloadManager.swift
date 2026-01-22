import Foundation

/// EasyTier下载管理器
@MainActor
class EasyTierDownloadManager: ObservableObject {
    static let shared = EasyTierDownloadManager()

    @Published var downloadState = EasyTierDownloadState()
    @Published var isWindowVisible = false

    private let easyTierService = EasyTierService.shared
    private var dismissCallback: (() -> Void)?

    /// 设置窗口关闭回调
    func setDismissCallback(_ callback: @escaping () -> Void) {
        dismissCallback = callback
    }

    /// 开始下载EasyTier
    func downloadEasyTier() async {
        do {
            // 重置状态
            downloadState.reset()
            downloadState.startDownload()

            // 显示下载弹窗
            showDownloadWindow()

            // 设置进度回调
            easyTierService.setProgressCallback { [weak self] fileName, completed, total in
                Task { @MainActor in
                    // 检查是否已取消
                    guard let self = self, !self.downloadState.isCancelled else { return }
                    self.downloadState.updateProgress(fileName: fileName, completed: completed, total: total)
                }
            }

            // 设置取消检查回调
            easyTierService.setCancelCallback { [weak self] in
                return self?.downloadState.isCancelled ?? false
            }

            // 开始下载
            try await easyTierService.downloadAndInstallEasyTier()

            // 检查是否被取消
            if downloadState.isCancelled {
                Logger.shared.info("EasyTier下载已被取消")
                cleanupCancelledDownload()
                return
            }

            // 下载完成 - 设置完成状态，稍后自动关闭窗口
            downloadState.isDownloading = false

            closeWindow()
        } catch {
            // 下载失败
            if !downloadState.isCancelled {
                let globalError = GlobalError.from(error)
                downloadState.setError(globalError.chineseMessage)
            }
        }
    }

    /// 取消下载
    func cancelDownload() {
        downloadState.cancel()
        // 取消状态会通过shouldCancel回调传递给EasyTierService
        // 立即关闭窗口
        cleanupCancelledDownload()
    }

    /// 重试下载
    func retryDownload() {
        Task {
            await downloadEasyTier()
        }
    }

    /// 显示下载窗口
    private func showDownloadWindow() {
        WindowManager.shared.openWindow(id: .easyTierDownload)
        isWindowVisible = true
    }

    /// 关闭窗口
    func closeWindow() {
        WindowManager.shared.closeWindow(id: .easyTierDownload)
        isWindowVisible = false
        downloadState.reset()
        dismissCallback?()
    }

    /// 清理取消的下载数据
    func cleanupCancelledDownload() {
        // 清理已下载的部分文件
        // 这里可以添加清理逻辑，比如删除部分下载的文件
        Logger.shared.info("Cleaning up cancelled EasyTier download")
        // 重置状态并关闭窗口
        closeWindow()
    }
}
