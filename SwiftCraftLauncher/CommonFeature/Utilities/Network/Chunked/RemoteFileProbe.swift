//
//  RemoteFileProbe.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// What a HEAD request told us about a remote file.
struct RemoteFileInfo: Sendable {
    let contentLength: Int64
    let acceptsRanges: Bool
    let etag: String?
    let lastModified: String?
}

/// Probes a remote file to decide whether chunked downloading is viable.
enum RemoteFileProbe {
    private static let acceptRangesHeader = "Accept-Ranges"
    private static let etagHeader = "ETag"
    private static let lastModifiedHeader = "Last-Modified"

    static func probe(url: URL, headers: [String: String]? = nil) async throws -> RemoteFileInfo {
        let session = NetworkSession.makeSession()
        defer { session.invalidateAndCancel() }

        let request = URLRequest(url: url)
            .method(APIClient.HTTPMethods.head)
            .headers(headers)

        let (_, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200 ... 299).contains(httpResponse.statusCode) else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw GlobalError.download(
                i18nKey: "error.download.cannot_get_file_size",
                level: .silent,
                message: "HEAD to \(url.absoluteString) returned status \(statusCode)",
            )
        }

        guard let rawLength = httpResponse.value(forHTTPHeaderField: APIClient.Header.contentLength),
              let contentLength = Int64(rawLength),
              contentLength > 0 else {
            throw GlobalError.download(
                i18nKey: "error.download.cannot_get_file_size",
                level: .silent,
                message: "HEAD to \(url.absoluteString) reported no Content-Length",
            )
        }

        let acceptsRanges = (httpResponse.value(forHTTPHeaderField: acceptRangesHeader) ?? "")
            .lowercased()
            .contains("bytes")

        return RemoteFileInfo(
            contentLength: contentLength,
            acceptsRanges: acceptsRanges,
            etag: httpResponse.value(forHTTPHeaderField: etagHeader),
            lastModified: httpResponse.value(forHTTPHeaderField: lastModifiedHeader),
        )
    }
}
