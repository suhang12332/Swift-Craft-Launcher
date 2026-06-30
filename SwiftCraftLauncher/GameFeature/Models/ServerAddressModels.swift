//
//  ServerAddressModels.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// A Minecraft server address with connection details.
struct ServerAddress: Codable, Identifiable, Hashable {
    /// The unique identifier for this server entry.
    let id: String

    /// The display name of the server.
    let name: String

    /// The server IP address or hostname.
    let address: String

    /// The server port. Defaults to 25565.
    let port: Int

    /// Whether the server icon is hidden.
    let hidden: Bool

    /// The optional server icon resource path.
    let icon: String?

    /// Whether the server accepts texture skins.
    let acceptTextures: Bool

    /// Creates a server address with the specified parameters.
    /// - Parameters:
    ///   - id: The unique identifier. Defaults to a new UUID string.
    ///   - name: The display name of the server.
    ///   - address: The server IP address or hostname.
    ///   - port: The server port. Defaults to 25565.
    ///   - hidden: Whether the server icon is hidden. Defaults to false.
    ///   - icon: The server icon resource path, if available.
    ///   - acceptTextures: Whether texture skins are accepted. Defaults to false.
    init(
        id: String = UUID().uuidString,
        name: String,
        address: String,
        port: Int = 25565,
        hidden: Bool = false,
        icon: String? = nil,
        acceptTextures: Bool = false
    ) {
        self.id = id
        self.name = name
        self.address = address
        self.port = port
        self.hidden = hidden
        self.icon = icon
        self.acceptTextures = acceptTextures
    }

    /// The full server address including port.
    var fullAddress: String {
        return "\(address):\(String(port))"
    }
}
