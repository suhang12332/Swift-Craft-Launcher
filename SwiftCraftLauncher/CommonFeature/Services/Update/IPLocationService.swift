//
//  IPLocationService.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Detects the user's geographic location by IP address and timezone.
@Observable
class IPLocationService {
    /// Timezone identifiers used in China.
    /// `Asia/Urumqi` is UTC+6; the others are UTC+8.
    private static let chinaTimeZones: Set<String> = [
        "Asia/Shanghai",
        "Asia/Chongqing",
        "Asia/Harbin",
        "Asia/Urumqi",
        "Asia/Hong_Kong",
        "Asia/Macau",
        "Asia/Taipei",
    ]

    init() { }

    /// Checks whether the user's IP is outside the current region, throwing on failure.
    /// Both the local timezone (one of ``chinaTimeZones``) and the country reported by
    /// Cloudflare's trace endpoint must be Chinese to be treated as domestic; any other
    /// timezone already implies foreign and skips the network request.
    /// - Returns: `true` if the user is considered foreign.
    /// - Throws: A `GlobalError` if detection fails.
    func isForeignIPThrowing() async throws -> Bool {
        // Both the timezone and the IP must be Chinese to return `false`.
        let timezone = TimeZone.current.identifier
        AppLog.common.debug("Current timezone: \(timezone)")
        guard Self.chinaTimeZones.contains(timezone) else {
            AppLog.common.debug("Timezone is not Chinese, treating as foreign")
            return true
        }

        // Timezone is Chinese — verify the IP location as well.
        let (data, statusCode) = try await APIClient.getUnchecked(url: URLConfig.API.IPLocation.currentLocation)

        guard statusCode == 200 else {
            AppLog.common.error("Cloudflare trace request returned non-200 status: \(statusCode)")
            throw GlobalError.network(
                i18nKey: "error.network.ip_location_failed",
                level: .notification,
                message: "Cloudflare trace request failed with HTTP \(statusCode)",
            )
        }

        guard let trace = CloudflareTraceResponse(data: data), let countryCode = trace.countryCode else {
            if let responseString = String(data: data, encoding: .utf8) {
                AppLog.common.error("Response content: \(responseString)")
            }
            throw GlobalError.validation(
                i18nKey: "error.validation.ip_location_parse_failed",
                level: .notification,
                message: "Failed to parse Cloudflare trace response (HTTP \(statusCode))",
            )
        }

        AppLog.common.debug("IP geolocation detection complete: country code = \(countryCode), is foreign = \(trace.isForeign)")

        return trace.isForeign
    }
}
