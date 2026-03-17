import Foundation

extension LauncherImportViewModel {
    // MARK: - Helper Methods

    /// 从实例路径推断启动器基础路径
    /// 向上查找包含 icons 文件夹的目录，如果找不到则使用实例路径的父目录的父目录
    func inferBasePath(from instancePath: URL) -> URL {
        let fileManager = FileManager.default
        var currentPath = instancePath

        // 向上查找，最多查找5层
        for _ in 0..<5 {
            let iconsPath = currentPath.appendingPathComponent("icons")
            if fileManager.fileExists(atPath: iconsPath.path) {
                return currentPath
            }
            let parentPath = currentPath.deletingLastPathComponent()
            if parentPath.path == currentPath.path {
                // 已经到达根目录
                break
            }
            currentPath = parentPath
        }

        // 如果找不到 icons 文件夹，使用实例路径的父目录的父目录作为 fallback
        return instancePath.deletingLastPathComponent().deletingLastPathComponent()
    }

    /// 下载图标
    func downloadIcon(from urlString: String, instanceName: String) async -> Data? {
        guard let url = URL(string: urlString) else { return nil }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)

            // 缓存图标
            let cacheDir = AppPaths.appCache.appendingPathComponent("imported_icons")
            try FileManager.default.createDirectory(
                at: cacheDir,
                withIntermediateDirectories: true
            )
            let cachedPath = cacheDir.appendingPathComponent("\(instanceName).png")
            try data.write(to: cachedPath)

            return data
        } catch {
            Logger.shared.warning("下载图标失败: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Computed Properties

    /// 获取当前选中实例的信息
    var currentInstanceInfo: ImportInstanceInfo? {
        guard let instancePath = selectedInstancePath else { return nil }

        // 从实例路径推断启动器基础路径
        let basePath = inferBasePath(from: instancePath)

        let parser = LauncherInstanceParserFactory.createParser(for: selectedLauncherType)
        do {
            if let info = try parser.parseInstance(at: instancePath, basePath: basePath) {
                // 验证必须有版本（只记录日志，不显示错误，错误会在导入时显示）
                guard !info.gameVersion.isEmpty else {
                    Logger.shared.warning("选中的实例没有游戏版本")
                    return nil
                }

                return info
            } else {
                Logger.shared.warning("解析实例返回 nil")
                return nil
            }
        } catch {
            Logger.shared.error("解析实例失败: \(error.localizedDescription)")
            return nil
        }
    }

    /// 检查当前选中的实例是否使用了支持的 Mod Loader
    var isModLoaderSupported: Bool {
        guard let info = currentInstanceInfo else { return false }
        return AppConstants.modLoaders.contains(info.modLoader.lowercased())
    }
}