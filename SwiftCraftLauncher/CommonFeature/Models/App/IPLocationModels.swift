//
//  IPLocationModels.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// A parsed response from Cloudflare's `cdn-cgi/trace` endpoint.
///
/// The endpoint returns plain-text `key=value` lines instead of JSON, e.g.:
/// ```
/// ip=203.0.113.1
/// loc=CN
/// colo=HKG
/// ```
struct CloudflareTraceResponse {
    /// All key-value pairs returned by the trace endpoint.
    let fields: [String: String]

    /// Parses a raw trace payload, returning `nil` when it is empty or not valid UTF-8.
    init?(data: Data) {
        guard let text = String(data: data, encoding: .utf8) else {
            return nil
        }

        var fields: [String: String] = [:]
        for line in text.split(whereSeparator: \.isNewline) {
            guard let separator = line.firstIndex(of: "=") else { continue }
            let key = String(line[..<separator])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let value = String(line[line.index(after: separator)...])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !key.isEmpty else { continue }
            fields[key] = value
        }

        guard !fields.isEmpty else {
            return nil
        }
        self.fields = fields
    }

    /// Whether the response contains a usable country code.
    var isSuccess: Bool {
        countryCode != nil
    }

    /// The two-letter country code reported by Cloudflare (e.g. `"CN"`).
    var countryCode: String? {
        guard let location = fields["loc"]?.uppercased(), !location.isEmpty else {
            return nil
        }
        return location
    }

    /// Whether the IP address is located in China.
    var isChina: Bool {
        countryCode == "CN"
    }

    /// Whether the IP address is located outside China.
    var isForeign: Bool {
        isSuccess && !isChina
    }
}
