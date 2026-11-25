//
//  MinecraftServerInfo.swift
//  CommonFeature
//
//  © 2025 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Represents information about a Minecraft server.
struct MinecraftServerInfo: Codable, Sendable {
    /// The server version information.
    struct Version: Codable, Sendable {
        let name: String
        let `protocol`: Int?
    }

    /// The player information.
    struct Players: Codable, Sendable {
        let max: Int
        let online: Int
        let sample: [Player]?

        struct Player: Codable, Sendable {
            let name: String
            let id: String?
        }
    }

    /// The server description (MOTD).
    struct Description: Codable, Sendable {
        let text: String?
        let extra: [DescriptionElement]?

        /// A description element that can be either a string or a nested Description object.
        enum DescriptionElement: Codable, Sendable {
            case string(String)
            case object(Description)

            init(from decoder: Decoder) throws {
                let container = try decoder.singleValueContainer()
                if let string = try? container.decode(String.self) {
                    self = .string(string)
                } else {
                    let object = try container.decode(Description.self)
                    self = .object(object)
                }
            }

            func encode(to encoder: Encoder) throws {
                var container = encoder.singleValueContainer()
                switch self {
                case let .string(string):
                    try container.encode(string)
                case let .object(description):
                    try container.encode(description)
                }
            }

            var plainText: String {
                switch self {
                case let .string(string):
                    return string
                case let .object(description):
                    return description.plainText
                }
            }
        }

        /// Returns the plain text description with formatting codes removed.
        var plainText: String {
            var result = ""
            if let text {
                result += stripFormatCodes(text)
            }
            if let extra {
                result += extra.map(\.plainText).joined()
            }
            return result
        }

        /// Removes Minecraft formatting codes from the text.
        private func stripFormatCodes(_ text: String) -> String {
            var result = text
            while let range = result.range(of: "§") {
                let startIndex = range.lowerBound
                let endIndex = result.index(startIndex, offsetBy: 2, limitedBy: result.endIndex) ?? result.endIndex
                result.removeSubrange(startIndex ..< endIndex)
            }
            return result
        }
    }

    let version: Version?
    let players: Players?
    let description: Description
    /// Base64-encoded server icon.
    let favicon: String?
    /// Mod information, if available.
    let modinfo: ModInfo?

    struct ModInfo: Codable, Sendable {
        let type: String
        let modList: [Mod]?

        struct Mod: Codable, Sendable {
            let modid: String
            let version: String
        }
    }
}
