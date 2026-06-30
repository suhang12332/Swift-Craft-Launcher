//
//  CategoryModels.swift
//  ResourceFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// A filter item with an identifier and display name.
struct FilterItem: Identifiable, Equatable, Hashable {
    let id: String
    let name: String
}

/// Project type string constants used for categorization.
enum ProjectType {
    static let modpack = "modpack"
    static let mod = "mod"
    static let datapack = "datapack"
    static let resourcepack = "resourcepack"
    static let shader = "shader"
    static let minecraftJavaServer = "minecraft_java_server"
}

/// Category header string constants for grouping filter categories.
enum CategoryHeader {
    static let categories = "categories"
    static let features = "features"
    static let resolutions = "resolutions"
    static let performanceImpact = "performance impact"
    static let environment = "environment"
    static let minecraftServerMeta = "minecraft_server_meta"
    static let minecraftServerGameplay = "minecraft_server_gameplay"
    static let minecraftServerFeatures = "minecraft_server_features"
    static let minecraftServerCommunity = "minecraft_server_community"
}

/// Localization key constants for filter section titles.
enum FilterTitle {
    static let category = "filter.category"
    static let environment = "filter.environment"
    static let behavior = "filter.behavior"
    static let resolutions = "filter.resolutions"
    static let performance = "filter.performance"
    static let version = "filter.version"
    static let serverMeta = "filter.server.meta"
    static let serverGameplay = "filter.server.gameplay"
    static let serverFeatures = "filter.server.features"
    static let serverCommunity = "filter.server.community"
}
