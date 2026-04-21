import Foundation
import UniformTypeIdentifiers

@MainActor
final class GameInfoDetailIOViewModel: ObservableObject {
    private let errorHandler: GlobalErrorHandler
    private let modScanner: ModScanner

    init(
        errorHandler: GlobalErrorHandler = AppServices.errorHandler,
        modScanner: ModScanner = AppServices.modScanner
    ) {
        self.errorHandler = errorHandler
        self.modScanner = modScanner
    }

    /// 扫描本地资源目录，返回 detailId Set（失败返回空集合，并上报 GlobalError）
    func scanAllDetailIds(query: String, gameName: String) async -> Set<String> {
        // Modpacks don't have a local directory to scan
        if query.lowercased() == ResourceType.modpack.rawValue {
            return []
        }

        guard let resourceDir = AppPaths.resourceDirectory(for: query, gameName: gameName) else {
            return []
        }

        guard FileManager.default.fileExists(atPath: resourceDir.path) else {
            return []
        }

        do {
            return try await modScanner.scanAllDetailIdsThrowing(in: resourceDir)
        } catch {
            let globalError = GlobalError.from(error)
            Logger.shared.error("扫描所有资源失败: \(globalError.chineseMessage)")
            errorHandler.handle(globalError)
            return []
        }
    }

    /// 保存游戏图标（支持 security-scoped），失败会走 GlobalErrorHandler，返回是否成功
    func saveGameIcon(from result: Result<[URL], Error>, gameName: String) async -> Bool {
        switch result {
        case .success(let urls):
            guard let url = urls.first else {
                let globalError = GlobalError.validation(
                    chineseMessage: "未选择文件",
                    i18nKey: "error.validation.no_file_selected",
                    level: .notification
                )
                errorHandler.handle(globalError)
                return false
            }

            guard url.startAccessingSecurityScopedResource() else {
                let globalError = GlobalError.fileSystem(
                    chineseMessage: "无法访问所选文件",
                    i18nKey: "error.filesystem.file_access_failed",
                    level: .notification
                )
                errorHandler.handle(globalError)
                return false
            }
            defer { url.stopAccessingSecurityScopedResource() }

            do {
                try await Task.detached(priority: .userInitiated) {
                    let imageData = try Data(contentsOf: url)
                    let optimizedImageData = GameIconProcessor.optimize(data: imageData)
                    let profileDir = AppPaths.profileDirectory(gameName: gameName)
                    let iconFileName = AppConstants.defaultGameIcon
                    let iconURL = profileDir.appendingPathComponent(iconFileName)
                    try FileManager.default.createDirectory(
                        at: profileDir,
                        withIntermediateDirectories: true
                    )
                    try optimizedImageData.write(to: iconURL)
                }.value

                Logger.shared.info("成功更新游戏图标: \(gameName)")
                return true
            } catch {
                let globalError = GlobalError.from(error)
                Logger.shared.error("更新游戏图标失败: \(globalError.chineseMessage)")
                errorHandler.handle(globalError)
                return false
            }

        case .failure(let error):
            let globalError = GlobalError.from(error)
            errorHandler.handle(globalError)
            return false
        }
    }
}
