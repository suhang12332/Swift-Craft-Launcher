//
//  IPLocationService.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Detects the user's geographic location by IP address and timezone.
class IPLocationService: ObservableObject {
    /// Chinese timezone identifier.
    private static let chinaTimeZone = "Asia/Shanghai"

    init() { }

    /// Checks whether the user's IP is outside the current region.
    /// Uses timezone detection as a fast local check, falls back to IP API if timezone is uncertain.
    /// - Returns: `true` if the IP is foreign, `false` if detection fails or the IP is domestic.
    func isForeignIP() async -> Bool {
        // Fast local check: if timezone is clearly Chinese, return false immediately.
        let timezone = TimeZone.current.identifier
        AppLog.common.debug("Current timezone: \(timezone)")
        if timezone == Self.chinaTimeZone {
            AppLog.common.debug("Timezone is Chinese, skipping IP detection")
            return false
        }

        // Timezone is non-Chinese or unknown — fall back to IP API for accurate detection.
        do {
            return try await isForeignIPThrowing()
        } catch {
            let globalError = GlobalError.from(error)
            AppLog.common.error("Failed to detect IP geolocation: \(globalError.localizedDescription)")
            // If both timezone and IP detection fail, assume foreign as a conservative default.
            return true
        }
    }

    /// Checks whether the user's IP is outside the current region, throwing on failure.
    /// - Returns: `true` if the IP is foreign.
    /// - Throws: A `GlobalError` if detection fails.
    func isForeignIPThrowing() async throws -> Bool {
        let (data, statusCode) = try await APIClient.getUnchecked(url: URLConfig.API.IPLocation.currentLocation)

        // Some APIs return non-200 status codes while still including data in the response body.
        let locationResponse: IPLocationResponse
        do {
            locationResponse = try JSONDecoder().decode(IPLocationResponse.self, from: data)
        } catch {
            AppLog.common.error("Failed to parse IP geolocation response: HTTP \(statusCode), error: \(error.localizedDescription)")
            if let responseString = String(data: data, encoding: .utf8) {
                AppLog.common.error("Response content: \(responseString)")
            }
            throw GlobalError.validation(
                i18nKey: "error.validation.ip_location_parse_failed",
                level: .notification,
                message: "Failed to parse IP location response (HTTP \(statusCode)): \(error.localizedDescription)",
            )
        }

        if statusCode != 200 {
            AppLog.common.error("IP geolocation API returned non-200 status: \(statusCode)")
        }

        guard locationResponse.isSuccess else {
            let errorMessage = locationResponse.reason ?? "IP geolocation detection failed"
            AppLog.common.error("IP geolocation detection failed: \(errorMessage), country code: \(locationResponse.countryCode ?? "unknown")")
            throw GlobalError.network(
                i18nKey: "error.network.ip_location_failed",
                level: .notification,
                message: "IP geolocation API failed: \(errorMessage), countryCode=\(locationResponse.countryCode ?? "unknown")",
            )
        }

        AppLog.common.debug("IP geolocation detection complete: country code = \(locationResponse.countryCode ?? "unknown"), is foreign = \(locationResponse.isForeign)")

        return locationResponse.isForeign
    }
}
