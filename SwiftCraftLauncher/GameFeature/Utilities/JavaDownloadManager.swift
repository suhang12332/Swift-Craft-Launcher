import Foundation

/// Java下载管理器
@MainActor
class JavaDownloadManager: ObservableObject {
    static let shared = JavaDownloadManager()

    @Published var downloadState = JavaDownloadState()
    @Published var isWindowVisible = false

    private let javaRuntimeService: JavaRuntimeService
    private let windowManager: WindowManager
    private var dismissCallback: (() -> Void)?
    private var currentDownloadTask: Task<Void, Error>?
    private var cancelRequested = false

    private init(
        javaRuntimeService: JavaRuntimeService = AppServices.javaRuntimeService,
        windowManager: WindowManager = AppServices.windowManager
    ) {
        self.javaRuntimeService = javaRuntimeService
        self.windowManager = windowManager
    }

    /// 设置窗口关闭回调
    func setDismissCallback(_ callback: @escaping () -> Void) {
        dismissCallback = callback
    }

    /// 开始下载Java运行时
    func downloadJavaRuntime(version: String) async {
        defer {
            currentDownloadTask = nil
            cancelRequested = false
        }
        do {
            // 重置状态
            downloadState.reset()
            downloadState.startDownload(version: version)
            cancelRequested = false

            // 显示下载弹窗
            showDownloadWindow()

            // 设置进度回调
            javaRuntimeService.setProgressCallback { [weak self] fileName, completed, total in
                Task { @MainActor in
                    // 检查是否已取消
                    guard let self = self, !self.downloadState.isCancelled else { return }
                    let progress = total > 0 ? Double(completed) / Double(total) : 0.0
                    self.downloadState.updateProgress(fileName: fileName, progress: progress)
                }
            }

            // 设置取消检查回调
            javaRuntimeService.setCancelCallback { [weak self] in
                return self?.cancelRequested ?? false
            }

            // 开始下载
            let task = Task { [javaRuntimeService] in
                try await javaRuntimeService.downloadJavaRuntime(for: version)
            }
            currentDownloadTask = task
            try await task.value

            // 检查是否被取消
            if downloadState.isCancelled || cancelRequested {
                Logger.shared.info("Java下载已被取消")
                cleanupCancelledDownload()
                return
            }

            // 下载完成 - 设置完成状态，稍后自动关闭窗口
            downloadState.isDownloading = false

            closeWindow()
        } catch {
            if error is CancellationError || downloadState.isCancelled || cancelRequested {
                Logger.shared.info("Java下载任务已取消")
                cleanupCancelledDownload()
                return
            }
            // 下载失败
            if !downloadState.isCancelled {
                downloadState.setError(error.localizedDescription)
            }
        }
    }

    /// 取消下载
    func cancelDownload() {
        guard downloadState.isDownloading else {
            closeWindow()
            return
        }
        cancelRequested = true
        downloadState.cancel()
        currentDownloadTask?.cancel()
    }

    /// 重试下载
    func retryDownload() {
        guard !downloadState.version.isEmpty else { return }
        Task {
            await downloadJavaRuntime(version: downloadState.version)
        }
    }

    /// 显示下载窗口
    private func showDownloadWindow() {
        windowManager.openWindow(id: .javaDownload)
        isWindowVisible = true
    }

    /// 关闭窗口
    func closeWindow() {
        windowManager.closeWindow(id: .javaDownload)
        isWindowVisible = false
        downloadState.reset()
        dismissCallback?()
    }

    /// 清理取消的下载数据
    func cleanupCancelledDownload() {
        // 清理已下载的部分文件
        // 可添加清理逻辑
        Logger.shared.info("Cleaning up cancelled Java download for version: \(downloadState.version)")
        // 重置状态并关闭窗口
        closeWindow()
    }
}
