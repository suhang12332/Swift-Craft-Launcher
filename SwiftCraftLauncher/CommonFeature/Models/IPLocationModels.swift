//
//  IPLocationModels.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// A geolocation response from the ipapi.co API.
struct IPLocationResponse: Codable {
    let countryCode: String?
    let error: Bool
    let reason: String?

    enum CodingKeys: String, CodingKey {
        case countryCode = "country_code"
        case error
        case reason
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        countryCode = try container.decodeIfPresent(String.self, forKey: .countryCode)
        error = try container.decodeIfPresent(Bool.self, forKey: .error) ?? false
        reason = try container.decodeIfPresent(String.self, forKey: .reason)
    }

    /// Whether the request succeeded.
    var isSuccess: Bool {
        return !error && countryCode != nil
    }

    /// Whether the IP address is located in China.
    var isChina: Bool {
        return countryCode == "CN"
    }

    /// Whether the IP address is located outside China.
    var isForeign: Bool {
        return isSuccess && !isChina
    }
}
