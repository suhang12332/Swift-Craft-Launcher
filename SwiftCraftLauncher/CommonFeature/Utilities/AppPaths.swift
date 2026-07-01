//
//  AppPaths.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Provides file system paths used throughout the application.
enum AppPaths {
    static var launcherSupportDirectory: URL {
        .applicationSupportDirectory.appendingPathComponent(Bundle.main.appName)
    }

    /// The root directory for authentication-related files.
    static var authDirectory: URL {
        launcherSupportDirectory.appendingPathComponent(AppConstants.DirectoryNames.auth, isDirectory: true)
    }

    static var runtimeDirectory: URL {
        launcherSupportDirectory.appendingPathComponent(AppConstants.DirectoryNames.runtime)
    }

    /// Returns the path to the Java executable for a given runtime version.
    static func javaExecutablePath(version: String) -> String {
        runtimeDirectory.appendingPathComponent(version).appendingPathComponent("jre.bundle/Contents/Home/bin/java").path
    }

    static var metaDirectory: URL {
        launcherSupportDirectory.appendingPathComponent(AppConstants.DirectoryNames.meta)
    }

    static var librariesDirectory: URL {
        metaDirectory.appendingPathComponent(AppConstants.DirectoryNames.libraries)
    }

    static var nativesDirectory: URL {
        metaDirectory.appendingPathComponent(AppConstants.DirectoryNames.natives)
    }

    static var assetsDirectory: URL {
        metaDirectory.appendingPathComponent(AppConstants.DirectoryNames.assets)
    }

    static var versionsDirectory: URL {
        metaDirectory.appendingPathComponent(AppConstants.DirectoryNames.versions)
    }

    static var profileRootDirectory: URL {
        let customPath = AppServices.generalSettingsManager.launcherWorkingDirectory
        let workingDirectory = customPath.isEmpty ? launcherSupportDirectory.path : customPath

        let baseURL = URL(fileURLWithPath: workingDirectory, isDirectory: true)
        return baseURL.appendingPathComponent(AppConstants.DirectoryNames.profiles, isDirectory: true)
    }

    static func profileDirectory(gameName: String) -> URL {
        profileRootDirectory.appendingPathComponent(gameName)
    }

    /// Returns the path to a game instance's `options.txt` file.
    static func optionsFile(gameName: String) -> URL {
        profileDirectory(gameName: gameName).appendingPathComponent(AppConstants.DirectoryNames.option)
    }

    static func modsDirectory(gameName: String) -> URL {
        profileDirectory(gameName: gameName).appendingPathComponent(AppConstants.DirectoryNames.mods)
    }

    static func datapacksDirectory(gameName: String) -> URL {
        profileDirectory(gameName: gameName).appendingPathComponent(AppConstants.DirectoryNames.datapacks)
    }

    static func shaderpacksDirectory(gameName: String) -> URL {
        profileDirectory(gameName: gameName).appendingPathComponent(AppConstants.DirectoryNames.shaderpacks)
    }

    static func resourcepacksDirectory(gameName: String) -> URL {
        profileDirectory(gameName: gameName).appendingPathComponent(AppConstants.DirectoryNames.resourcepacks)
    }

    static func schematicsDirectory(gameName: String) -> URL {
        profileDirectory(gameName: gameName).appendingPathComponent(AppConstants.DirectoryNames.schematics, isDirectory: true)
    }

    static let profileSubdirectories = [
        AppConstants.DirectoryNames.shaderpacks,
        AppConstants.DirectoryNames.resourcepacks,
        AppConstants.DirectoryNames.mods,
        AppConstants.DirectoryNames.datapacks,
        AppConstants.DirectoryNames.crashReports,
    ]

    /// The application logs directory, preferring the system standard location.
    static var logsDirectory: URL {
        if let libraryDirectory = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first {
            return libraryDirectory.appendingPathComponent("Logs", isDirectory: true)
                .appendingPathComponent(Bundle.main.appName, isDirectory: true)
        }
        return launcherSupportDirectory.appendingPathComponent(AppConstants.DirectoryNames.logs, isDirectory: true)
    }
}

extension AppPaths {
    static func resourceDirectory(for type: String, gameName: String) -> URL? {
        switch type.lowercased() {
        case ResourceType.mod.rawValue: return modsDirectory(gameName: gameName)
        case ResourceType.datapack.rawValue: return datapacksDirectory(gameName: gameName)
        case ResourceType.shader.rawValue: return shaderpacksDirectory(gameName: gameName)
        case ResourceType.resourcepack.rawValue: return resourcepacksDirectory(gameName: gameName)
        default: return nil
        }
    }

    /// Infers the resource type from the file's parent directory name.
    /// - Parameter fileURL: The URL of the local resource file.
    /// - Returns: A resource type string, or `nil` if the type cannot be determined.
    static func resourceType(for fileURL: URL) -> String? {
        let parentDirName = fileURL.deletingLastPathComponent().lastPathComponent.lowercased()

        switch parentDirName {
        case AppConstants.DirectoryNames.mods.lowercased():
            return ResourceType.mod.rawValue
        case AppConstants.DirectoryNames.shaderpacks.lowercased():
            return ResourceType.shader.rawValue
        case AppConstants.DirectoryNames.resourcepacks.lowercased():
            return ResourceType.resourcepack.rawValue
        case AppConstants.DirectoryNames.datapacks.lowercased():
            return ResourceType.datapack.rawValue
        default:
            return nil
        }
    }

    /// The application cache directory, preferring the system standard location.
    static var appCache: URL {
        if let cachesDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first {
            return cachesDirectory.appendingPathComponent(Bundle.main.identifier)
        }
        AppLog.common.error("Unable to get system cache directory, using Cache under Application Support")
        return launcherSupportDirectory.appendingPathComponent("Cache", isDirectory: true)
    }

    /// The data directory for application-specific storage.
    static var dataDirectory: URL {
        launcherSupportDirectory.appendingPathComponent(AppConstants.DirectoryNames.data, isDirectory: true)
    }

    /// The directory for storing local skin library files.
    static var skinsDirectory: URL {
        dataDirectory.appendingPathComponent("skins", isDirectory: true)
    }

    /// The path to the game version database file.
    static var gameVersionDatabase: URL {
        dataDirectory.appendingPathComponent("data.db")
    }
}
