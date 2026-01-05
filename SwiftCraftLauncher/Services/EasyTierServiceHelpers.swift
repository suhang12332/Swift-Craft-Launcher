//
//  EasyTierServiceHelpers.swift
//  SwiftCraftLauncher
//
//  Helper types for EasyTierService
//

import Foundation

// MARK: - Progress and Cancel Actors

/// 线程安全的进度回调actor
actor EasyTierProgressActor {
    private var callback: ((String, Int, Int) -> Void)?

    func setCallback(_ callback: @escaping (String, Int, Int) -> Void) {
        self.callback = callback
    }

    func callProgressUpdate(_ fileName: String, _ completed: Int, _ total: Int) {
        callback?(fileName, completed, total)
    }
}

/// 线程安全的取消检查actor
actor EasyTierCancelActor {
    private var callback: (() -> Bool)?

    func setCallback(_ callback: @escaping () -> Bool) {
        self.callback = callback
    }

    func shouldCancel() -> Bool {
        return callback?() ?? false
    }
}

/// 下载进度跟踪器
class EasyTierDownloadProgressTracker: NSObject, URLSessionDownloadDelegate {
    private let progressCallback: (Int64, Int64) -> Void
    private let totalFileSize: Int64
    var completionHandler: ((Result<URL, Error>) -> Void)?

    init(totalSize: Int64, progressCallback: @escaping (Int64, Int64) -> Void) {
        self.totalFileSize = totalSize
        self.progressCallback = progressCallback
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        let actualTotalSize = totalBytesExpectedToWrite > 0 ? totalBytesExpectedToWrite : totalFileSize

        if actualTotalSize > 0 {
            DispatchQueue.main.async { [weak self] in
                self?.progressCallback(totalBytesWritten, actualTotalSize)
            }
        }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        completionHandler?(.success(location))
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            completionHandler?(.failure(error))
        }
    }
}

// MARK: - EasyTierService Download Helpers Extension

extension EasyTierService {
    /// 确保文件有执行权限
    /// - Parameter filePath: 文件路径
    /// - Throws: GlobalError 当设置权限失败时
    func ensureExecutablePermissions(at filePath: String) throws {
        let fileManager = FileManager.default
        guard let attributes = try? fileManager.attributesOfItem(atPath: filePath),
              let permissions = attributes[.posixPermissions] as? Int else {
            throw GlobalError.fileSystem(
                chineseMessage: "无法读取文件权限: \(filePath)",
                i18nKey: "error.filesystem.permission_read_failed",
                level: .popup
            )
        }

        // 确保有执行权限
        if (permissions & 0o111) == 0 {
            var mutableAttributes = attributes
            mutableAttributes[.posixPermissions] = permissions | 0o111
            try fileManager.setAttributes(mutableAttributes, ofItemAtPath: filePath)
        }
    }

    /// 获取远程文件大小
    func getFileSize(from url: URL) async throws -> Int64 {
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"

        let (_, httpResponse) = try await APIClient.performRequestWithResponse(request: request)

        guard httpResponse.statusCode == 200 else {
            throw GlobalError.download(
                chineseMessage: "无法获取文件大小 - HTTP状态码: \(httpResponse.statusCode)",
                i18nKey: "error.download.cannot_get_file_size",
                level: .popup
            )
        }

        guard let contentLength = httpResponse.value(forHTTPHeaderField: "Content-Length"),
              let fileSize = Int64(contentLength) else {
            throw GlobalError.download(
                chineseMessage: "无法获取文件大小 - 缺少或无效的Content-Length头部",
                i18nKey: "error.download.cannot_get_file_size",
                level: .popup
            )
        }

        return fileSize
    }

    /// 下载 ZIP 文件并显示字节大小进度
    func downloadZipWithProgress(
        session: URLSession,
        from url: URL,
        to destinationURL: URL,
        progressTracker: EasyTierDownloadProgressTracker
    ) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            progressTracker.completionHandler = { result in
                switch result {
                case .success(let tempURL):
                    do {
                        let fileManager = FileManager.default

                        // 如果目标文件已存在，先删除
                        if fileManager.fileExists(atPath: destinationURL.path) {
                            try fileManager.removeItem(at: destinationURL)
                        }

                        // 移动临时文件到目标位置
                        try fileManager.moveItem(at: tempURL, to: destinationURL)
                        continuation.resume()
                    } catch {
                        Logger.shared.error("移动下载文件失败: \(error.localizedDescription)")
                        continuation.resume(throwing: error)
                    }
                case .failure(let error):
                    Logger.shared.error("下载失败: \(error.localizedDescription)")
                    continuation.resume(throwing: error)
                }
            }

            let downloadTask = session.downloadTask(with: url)
            downloadTask.resume()
        }
    }
}
