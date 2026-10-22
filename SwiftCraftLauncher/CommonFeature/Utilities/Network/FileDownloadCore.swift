//
//  FileDownloadCore.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Provides core utilities for downloading files, including URL parsing, directory setup, and SHA-1 validation.
/// A non-2xx HTTP status observed while downloading.
enum DownloadHTTPStatusError: Error {
    case httpStatus(Int)
}

/// Retry policy shared by download paths.
///
/// The single-stream path keeps its own private equivalent for now; new code
/// uses this so the two can later be unified without touching that path.
enum DownloadRetryPolicy {
    static let maxRetryCount = 3

    static func shouldRetry(_ error: Error) -> Bool {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut,
                 .cannotFindHost,
                 .cannotConnectToHost,
                 .networkConnectionLost,
                 .dnsLookupFailed,
                 .notConnectedToInternet,
                 .resourceUnavailable:
                return true
            default:
                return false
            }
        }

        if case let DownloadHTTPStatusError.httpStatus(statusCode) = error {
            return statusCode == 408 || statusCode == 429 || (500 ... 599).contains(statusCode)
        }

        return false
    }

    /// Exponential backoff capped at 4 seconds: 0.5s, 1s, 2s.
    static func delayNanoseconds(for attempt: Int) -> UInt64 {
        let seconds = min(pow(2.0, Double(attempt - 1)) * 0.5, 4.0)
        return UInt64(seconds * 1_000_000_000)
    }
}

enum FileDownloadCore {
    static func parseURL(from urlString: String) throws -> URL {
        try autoreleasepool {
            guard let url = URL(string: urlString) else {
                throw GlobalError.validation(
                    i18nKey: "error.validation.invalid_download_url",
                    level: .notification,
                    message: "Failed to parse URL string: \"\(urlString)\"",
                )
            }
            return url
        }
    }

    static func ensureParentDirectory(for destinationURL: URL, fileManager: FileManager = .default) throws {
        do {
            try fileManager.createDirectory(
                at: destinationURL.deletingLastPathComponent(),
                withIntermediateDirectories: true,
            )
        } catch {
            throw GlobalError.fileSystem(
                i18nKey: "error.filesystem.download_directory_creation_failed",
                level: .notification,
                message: "Cannot create parent directory for \(destinationURL.path): \(error.localizedDescription)",
            )
        }
    }

    static func existingFileSizeIfReusable(
        at destinationURL: URL,
        expectedSha1: String?,
        fileManager: FileManager = .default,
    ) async -> Int64? {
        guard fileManager.fileExists(atPath: destinationURL.path) else {
            return nil
        }

        let shouldCheckSha1 = (expectedSha1?.isEmpty == false)
        if shouldCheckSha1, let expectedSha1 {
            do {
                let actualSha1 = try await SHA1Calculator.sha1InBackground(ofFileAt: destinationURL)
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

    static func validateSHA1IfNeeded(for fileURL: URL, expectedSha1: String?) async throws {
        guard let expectedSha1, !expectedSha1.isEmpty else { return }
        let actualSha1 = try await SHA1Calculator.sha1InBackground(ofFileAt: fileURL)
        if actualSha1 != expectedSha1 {
            throw GlobalError.validation(
                i18nKey: "error.validation.sha1_check_failed",
                level: .notification,
                message: "SHA1 mismatch for \(fileURL.path): expected \(expectedSha1), got \(actualSha1)",
            )
        }
    }

    static func moveDownloadedFile(
        from tempURL: URL,
        to destinationURL: URL,
        fileManager: FileManager = .default,
    ) throws {
        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.replaceItem(
                at: destinationURL,
                withItemAt: tempURL,
                backupItemName: nil,
                options: [],
                resultingItemURL: nil,
            )
        } else {
            try fileManager.moveItem(at: tempURL, to: destinationURL)
        }
    }
}
