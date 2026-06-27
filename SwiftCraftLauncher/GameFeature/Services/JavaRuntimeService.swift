import Foundation
import ZIPFoundation

/// Java运行时数据服务
class JavaRuntimeService {
    static let shared = JavaRuntimeService()

    private let generalSettingsManager: GeneralSettingsManager

    private init(generalSettingsManager: GeneralSettingsManager = AppServices.generalSettingsManager) {
        self.generalSettingsManager = generalSettingsManager
    }

    /// ARM平台专用版本的Zulu JDK配置
    private static let armJavaVersions: [String: URL] = [
        "jre-legacy": URLConfig.API.JavaRuntimeARM.jreLegacy,
        "java-runtime-alpha": URLConfig.API.JavaRuntimeARM.javaRuntimeAlpha,
        "java-runtime-beta": URLConfig.API.JavaRuntimeARM.javaRuntimeBeta,
    ]

    /// Intel平台专用版本的Zulu JDK配置
    private static let intelJavaVersions: [String: URL] = [
        "jre-legacy": URLConfig.API.JavaRuntimeIntel.jreLegacy,
        "java-runtime-alpha": URLConfig.API.JavaRuntimeIntel.javaRuntimeAlpha,
        "java-runtime-beta": URLConfig.API.JavaRuntimeIntel.javaRuntimeBeta,
    ]

    /// 获取当前架构对应的特供运行时URL
    func specialJavaRuntimeURL(for version: String) -> URL? {
        switch Architecture.current {
        case .arm64:
            return Self.armJavaVersions[version]
        case .x86_64:
            return Self.intelJavaVersions[version]
        }
    }

    /// 解析Java运行时API并获取gamecore平台支持的版本名称
    func getGamecoreSupportedVersions() async throws -> [String] {
        let json = try await fetchJavaRuntimeAPI()
        guard let gamecore = json["gamecore"] as? [String: Any] else {
            throw GlobalError.validation(
                chineseMessage: "未找到gamecore平台数据",
                i18nKey: "error.validation.gamecore_not_found",
                level: .notification
            )
        }

        let versionNames = Array(gamecore.keys)
        return versionNames
    }

    /// 根据当前系统（macOS）和CPU架构获取对应的Java运行时数据
    func getMacJavaRuntimeData() async throws -> [String: Any] {
        let json = try await fetchJavaRuntimeAPI()
        let platform = getCurrentMacPlatform()
        guard let platformData = json[platform] as? [String: Any] else {
            throw GlobalError.validation(
                chineseMessage: "未找到\(platform)平台数据",
                i18nKey: "error.validation.platform_data_not_found",
                level: .notification
            )
        }

        return platformData
    }

    /// 根据传入的版本名称获取对应的Java运行时数据
    func getMacJavaRuntimeData(for version: String) async throws -> [[String: Any]] {
        let platformData = try await getMacJavaRuntimeData()
        guard let versionData = platformData[version] as? [[String: Any]] else {
            Logger.shared.error("版本 \(version) 的数据类型不正确，期望 [[String: Any]]，实际: \(type(of: platformData[version]))")
            throw GlobalError.validation(
                chineseMessage: "未找到版本 \(version) 的数据",
                i18nKey: "error.validation.version_data_not_found",
                level: .notification
            )
        }

        return versionData
    }

    /// 获取指定版本的manifest URL
    func getManifestURL(for version: String) async throws -> String {
        let versionData = try await getMacJavaRuntimeData(for: version)
        // 版本数据是一个数组，取第一个元素
        guard let firstVersion = versionData.first,
              let manifest = firstVersion["manifest"] as? [String: Any],
              let manifestURL = manifest["url"] as? String else {
            Logger.shared.error("无法解析版本 \(version) 的数据结构")
            throw GlobalError.validation(
                chineseMessage: "未找到版本 \(version) 的manifest URL",
                i18nKey: "error.validation.manifest_url_not_found",
                level: .notification
            )
        }

        Logger.shared.info("找到版本 \(version) 的manifest URL: \(manifestURL)")
        return manifestURL
    }

    /// 获取Java运行时API数据
    private func fetchJavaRuntimeAPI() async throws -> [String: Any] {
        let url = URLConfig.API.JavaRuntime.allRuntimes
        let data = try await fetchDataFromURL(url.absoluteString)

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw GlobalError.validation(
                chineseMessage: "解析JSON失败",
                i18nKey: "error.validation.json_parse_failed",
                level: .notification
            )
        }

        return json
    }

    /// 下载指定URL的数据
    /// - Parameter urlString: URL字符串
    /// - Returns: 下载的数据
    private func fetchDataFromURL(_ urlString: String) async throws -> Data {
        guard let url = URL(string: urlString) else {
            throw GlobalError.validation(
                chineseMessage: "无效的URL",
                i18nKey: "error.validation.invalid_url",
                level: .notification
            )
        }
        return try await APIClient.get(url: url)
    }

    /// 获取当前macOS平台标识
    private func getCurrentMacPlatform() -> String {
        return Architecture.current.macPlatformId
    }
}
