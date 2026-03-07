import Foundation

final class AuthlibInjectorService {
    static let shared = AuthlibInjectorService()

    private let officialPrefix = "https://authlib-injector.yushi.moe/"
    private let mirrorPrefix = "https://bmclapi2.bangbang93.com/mirrors/authlib-injector/"

    private init() {}

    func ensureJarDownloaded() async throws -> URL {
        let destinationURL = AppPaths.authlibInjectorJar
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            return destinationURL
        }

        let metadata = try await fetchLatestMetadata()
        do {
            _ = try await DownloadManager.downloadFile(
                urlString: metadata.downloadURL,
                destinationURL: destinationURL
            )
            return destinationURL
        } catch {
            Logger.shared.warning("从官方地址下载 authlib-injector 失败，尝试 BMCLAPI 镜像: \(error.localizedDescription)")
            let mirrorURL = metadata.downloadURL.replacingOccurrences(
                of: officialPrefix,
                with: mirrorPrefix
            )
            guard mirrorURL != metadata.downloadURL else {
                throw error
            }

            _ = try await DownloadManager.downloadFile(
                urlString: mirrorURL,
                destinationURL: destinationURL
            )
            return destinationURL
        }
    }

    private func fetchLatestMetadata() async throws -> AuthlibInjectorLatestMetadata {
        let officialURL = URLConfig.API.AuthlibInjector.latestMetadata
        do {
            return try await fetchLatestMetadata(from: officialURL)
        } catch {
            Logger.shared.warning("获取 authlib-injector 元数据失败，尝试 BMCLAPI 镜像: \(error.localizedDescription)")
            let mirrorString = officialURL.absoluteString.replacingOccurrences(
                of: officialPrefix,
                with: mirrorPrefix
            )
            guard mirrorString != officialURL.absoluteString,
                  let mirrorURL = URL(string: mirrorString)
            else {
                throw error
            }

            return try await fetchLatestMetadata(from: mirrorURL)
        }
    }

    private func fetchLatestMetadata(from url: URL) async throws -> AuthlibInjectorLatestMetadata {
        let data = try await APIClient.get(url: url)
        do {
            return try JSONDecoder().decode(AuthlibInjectorLatestMetadata.self, from: data)
        } catch {
            throw GlobalError.validation(
                chineseMessage: "解析 authlib-injector 元数据失败: \(error.localizedDescription)",
                i18nKey: "error.validation.authlib_injector_metadata_parse_failed",
                level: .notification
            )
        }
    }
}

private struct AuthlibInjectorLatestMetadata: Codable {
    let version: String
    let downloadURL: String

    enum CodingKeys: String, CodingKey {
        case version
        case downloadURL = "download_url"
    }
}
