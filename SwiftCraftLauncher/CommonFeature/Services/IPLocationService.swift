//
//  IPLocationService.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Detects the user's geographic location by IP address.
@MainActor
class IPLocationService: ObservableObject {
    static let shared = IPLocationService()

    private init() { }

    /// Checks whether the user's IP is outside the current region.
    /// - Returns: `true` if the IP is foreign, `false` if detection fails or the IP is domestic.
    func isForeignIP() async -> Bool {
        do {
            return try await isForeignIPThrowing()
        } catch {
            let globalError = GlobalError.from(error)
            Logger.shared.error("检测IP地理位置失败: \(globalError.chineseMessage)")
            return false
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
            Logger.shared.error("解析IP地理位置响应失败: HTTP \(statusCode), error: \(error.localizedDescription)")
            if let responseString = String(data: data, encoding: .utf8) {
                Logger.shared.error("响应内容: \(responseString)")
            }
            throw GlobalError.validation(
                chineseMessage: "解析IP地理位置响应失败: \(error.localizedDescription)",
                i18nKey: "error.validation.ip_location_parse_failed",
                level: .notification,
            )
        }

        if statusCode != 200 {
            Logger.shared.warning("IP地理位置API返回非200状态码: \(statusCode)")
        }

        guard locationResponse.isSuccess else {
            let errorMessage = locationResponse.reason ?? "IP地理位置检测失败"
            Logger.shared.error("IP地理位置检测失败: \(errorMessage), 国家代码: \(locationResponse.countryCode ?? "未知")")
            throw GlobalError.network(
                chineseMessage: errorMessage,
                i18nKey: "error.network.ip_location_failed",
                level: .notification,
            )
        }

        Logger.shared.debug("IP地理位置检测完成: 国家代码 = \(locationResponse.countryCode ?? "未知"), 是否为国外 = \(locationResponse.isForeign)")

        return locationResponse.isForeign
    }
}
