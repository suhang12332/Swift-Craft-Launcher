import Foundation

/// Java管理器
class JavaManager {
    static let shared = JavaManager()

    private let fileManager = FileManager.default

    func findJavaExecutable(version: String) -> String {

        let javaPath = AppPaths.runtimeDirectory.appendingPathComponent(version).appendingPathComponent("jre.bundle/Contents/Home/bin/java")

        if fileManager.fileExists(atPath: javaPath.path) {
            return javaPath.path
        }

        return ""
    }

    /// 检查Java是否存在，如果不存在则使用进度窗口下载
    /// - Parameter version: Java版本
    func ensureJavaExists(version: String) async {
        // 检查Java是否已存在
        let javaPath = findJavaExecutable(version: version)
        if !javaPath.isEmpty {
            Logger.shared.info("Java版本 \(version) 已存在")
            return
        }

        // 如果不存在，则使用进度窗口下载Java运行时
        Logger.shared.info("Java版本 \(version) 不存在，开始下载...")
        await JavaDownloadManager.shared.downloadJavaRuntime(version: version)
        Logger.shared.info("Java版本 \(version) 下载完成")
    }
}
