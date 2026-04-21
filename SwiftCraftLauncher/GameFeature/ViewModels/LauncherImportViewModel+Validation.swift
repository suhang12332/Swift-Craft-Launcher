import Foundation

extension LauncherImportViewModel {
    // MARK: - Instance Validation

    /// 自动填充游戏名到输入框（如果输入框为空）
    func autoFillGameNameIfNeeded() {
        guard let instancePath = selectedInstancePath else { return }

        // 如果游戏名已经填写，不自动填充
        guard gameNameValidator.gameName.isEmpty else { return }

        // 从实例路径推断启动器基础路径
        let basePath = inferBasePath(from: instancePath)
        let parser = LauncherInstanceParserFactory.createParser(for: selectedLauncherType)

        // 解析实例信息并填充游戏名
        if let info = try? parser.parseInstance(at: instancePath, basePath: basePath) {
            gameNameValidator.gameName = info.gameName
        }
    }

    /// 检查 Mod Loader 是否支持，如果不支持则显示通知
    func checkAndNotifyUnsupportedModLoader() {
        guard let info = currentInstanceInfo else { return }

        // 检查 Mod Loader 是否支持
        guard !AppConstants.modLoaders.contains(info.modLoader.lowercased()) else { return }

        // 如果不支持，显示通知
        let supportedModLoadersList = AppConstants.modLoaders.joined(separator: "、")
        let instanceName = selectedInstancePath?.lastPathComponent ?? "Unknown"
        let chineseMessage = "实例 \(instanceName) 使用了不支持的 Mod Loader (\(info.modLoader))，仅支持 \(supportedModLoadersList)"

        errorHandler.handle(
            GlobalError.fileSystem(
                chineseMessage: chineseMessage,
                i18nKey: "error.filesystem.unsupported_mod_loader",
                level: .notification
            )
        )
    }

    /// 验证选择的实例文件夹是否有效
    /// 所有启动器都需要直接选择实例文件夹
    func validateInstance(at instancePath: URL) -> Bool {
        let parser = LauncherInstanceParserFactory.createParser(for: selectedLauncherType)
        let fileManager = FileManager.default

        // 检查路径是否存在且为目录
        guard fileManager.fileExists(atPath: instancePath.path) else {
            return false
        }

        let resourceValues = try? instancePath.resourceValues(forKeys: [.isDirectoryKey])
        guard resourceValues?.isDirectory == true else {
            return false
        }

        // 验证是否为有效实例
        return parser.isValidInstance(at: instancePath)
    }
}
