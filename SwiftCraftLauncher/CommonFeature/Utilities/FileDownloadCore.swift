import Foundation

enum FileDownloadCore {
    private static let githubPrefix = "https://github.com/"
    private static let rawGithubPrefix = "https://raw.githubusercontent.com/"
    private static let githubHost = "github.com"
    private static let rawGithubHost = "raw.githubusercontent.com"

    static func parseURL(from urlString: String) throws -> URL {
        try autoreleasepool {
            guard let url = URL(string: urlString) else {
                throw GlobalError.validation(
                    chineseMessage: "无效的下载地址",
                    i18nKey: "error.validation.invalid_download_url",
                    level: .notification
                )
            }
            return url
        }
    }

    static func normalizedDownloadURL(from originalURL: URL) -> URL {
        autoreleasepool {
            let needsProxy: Bool
            if let host = originalURL.host {
                needsProxy = host == githubHost || host == rawGithubHost
            } else {
                let absoluteString = originalURL.absoluteString
                needsProxy = absoluteString.hasPrefix(githubPrefix) || absoluteString.hasPrefix(rawGithubPrefix)
            }
            return needsProxy ? URLConfig.applyGitProxyIfNeeded(originalURL) : originalURL
        }
    }

    static func ensureParentDirectory(for destinationURL: URL, fileManager: FileManager = .default) throws {
        do {
            try fileManager.createDirectory(
                at: destinationURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
        } catch {
            throw GlobalError.fileSystem(
                chineseMessage: "创建目标目录失败",
                i18nKey: "error.filesystem.download_directory_creation_failed",
                level: .notification
            )
        }
    }

    static func existingFileSizeIfReusable(
        at destinationURL: URL,
        expectedSha1: String?,
        fileManager: FileManager = .default
    ) -> Int64? {
        guard fileManager.fileExists(atPath: destinationURL.path) else {
            return nil
        }

        let shouldCheckSha1 = (expectedSha1?.isEmpty == false)
        if shouldCheckSha1, let expectedSha1 {
            do {
                let actualSha1 = try autoreleasepool {
                    try SHA1Calculator.sha1(ofFileAt: destinationURL)
                }
                guard actualSha1 == expectedSha1 else {
                    return nil
                }
            } catch {
                return nil
            }
        }

        if let attributes = try? fileManager.attributesOfItem(atPath: destinationURL.path),
           let fileSize = attributes[.size] as? Int64 {
            return fileSize
        }
        return 0
    }

    static func validateSHA1IfNeeded(for fileURL: URL, expectedSha1: String?) throws {
        guard let expectedSha1, !expectedSha1.isEmpty else { return }
        let actualSha1 = try autoreleasepool {
            try SHA1Calculator.sha1(ofFileAt: fileURL)
        }
        if actualSha1 != expectedSha1 {
            throw GlobalError.validation(
                chineseMessage: "SHA1 校验失败",
                i18nKey: "error.validation.sha1_check_failed",
                level: .notification
            )
        }
    }

    static func moveDownloadedFile(
        from tempURL: URL,
        to destinationURL: URL,
        fileManager: FileManager = .default
    ) throws {
        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.replaceItem(
                at: destinationURL,
                withItemAt: tempURL,
                backupItemName: nil,
                options: [],
                resultingItemURL: nil
            )
        } else {
            try fileManager.moveItem(at: tempURL, to: destinationURL)
        }
    }
}
