//
//  AppConstantsTests.swift
//  SwiftCraftLauncherTests
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

@testable import SwiftCraftLauncher
import XCTest

final class AppConstantsTests: XCTestCase {
    func testDirectoryNames_values() {
        XCTAssertEqual(AppConstants.DirectoryNames.mods, "mods")
        XCTAssertEqual(AppConstants.DirectoryNames.libraries, "libraries")
        XCTAssertEqual(AppConstants.DirectoryNames.natives, "natives")
        XCTAssertEqual(AppConstants.DirectoryNames.assets, "assets")
        XCTAssertEqual(AppConstants.DirectoryNames.versions, "versions")
        XCTAssertEqual(AppConstants.DirectoryNames.shaderpacks, "shaderpacks")
        XCTAssertEqual(AppConstants.DirectoryNames.resourcepacks, "resourcepacks")
        XCTAssertEqual(AppConstants.DirectoryNames.datapacks, "datapacks")
        XCTAssertEqual(AppConstants.DirectoryNames.saves, "saves")
        XCTAssertEqual(AppConstants.DirectoryNames.screenshots, "screenshots")
        XCTAssertEqual(AppConstants.DirectoryNames.logs, "logs")
        XCTAssertEqual(AppConstants.DirectoryNames.profiles, "profiles")
        XCTAssertEqual(AppConstants.DirectoryNames.config, "config")
        XCTAssertEqual(AppConstants.DirectoryNames.option, "options.txt")
    }

    func testFileExtensions_values() {
        XCTAssertEqual(AppConstants.FileExtensions.jar, "jar")
        XCTAssertEqual(AppConstants.FileExtensions.png, "png")
        XCTAssertEqual(AppConstants.FileExtensions.zip, "zip")
        XCTAssertEqual(AppConstants.FileExtensions.json, "json")
        XCTAssertEqual(AppConstants.FileExtensions.log, "log")
        XCTAssertEqual(AppConstants.FileExtensions.mrpack, "mrpack")
    }

    func testURLCacheConfig_values() {
        XCTAssertEqual(AppConstants.URLCacheConfig.memoryCapacity, 2 * 1024 * 1024)
        XCTAssertEqual(AppConstants.URLCacheConfig.diskCapacity, 10 * 1024 * 1024)
    }

    func testUserDefaultsKeys_allExist() {
        XCTAssertFalse(AppConstants.UserDefaultsKeys.userProfiles.isEmpty)
        XCTAssertFalse(AppConstants.UserDefaultsKeys.currentPlayerId.isEmpty)
        XCTAssertFalse(AppConstants.UserDefaultsKeys.aiProvider.isEmpty)
        XCTAssertFalse(AppConstants.UserDefaultsKeys.globalXms.isEmpty)
        XCTAssertFalse(AppConstants.UserDefaultsKeys.globalXmx.isEmpty)
        XCTAssertFalse(AppConstants.UserDefaultsKeys.themeMode.isEmpty)
    }

    func testKeychainAccounts_keys() {
        XCTAssertEqual(AppConstants.KeychainAccounts.aiSettings, "aiSettings")
    }

    func testKeychainKeys_keys() {
        XCTAssertEqual(AppConstants.KeychainKeys.apiKey, "apiKey")
        XCTAssertEqual(AppConstants.KeychainKeys.authCredential, "authCredential")
    }

    func testMinecraftVersions_featureBaseline() {
        XCTAssertEqual(AppConstants.MinecraftVersions.featureBaseline, "1.13")
    }

    func testEnvironmentTypes_values() {
        XCTAssertEqual(AppConstants.EnvironmentTypes.client, "client")
        XCTAssertEqual(AppConstants.EnvironmentTypes.server, "server")
    }

    func testProcessorPlaceholders_values() {
        XCTAssertEqual(AppConstants.ProcessorPlaceholders.side, "{SIDE}")
        XCTAssertEqual(AppConstants.ProcessorPlaceholders.version, "{VERSION}")
        XCTAssertEqual(AppConstants.ProcessorPlaceholders.versionName, "{VERSION_NAME}")
        XCTAssertEqual(AppConstants.ProcessorPlaceholders.libraryDir, "{LIBRARY_DIR}")
        XCTAssertEqual(AppConstants.ProcessorPlaceholders.workingDir, "{WORKING_DIR}")
    }

    func testDatabaseTables_values() {
        XCTAssertEqual(AppConstants.DatabaseTables.gameVersions, "game_versions")
        XCTAssertEqual(AppConstants.DatabaseTables.modCache, "mod_cache")
    }

    func testAuthlibInjector_version() {
        XCTAssertEqual(AppConstants.AuthlibInjector.version, "1.2.7")
    }

    func testAuthlibInjector_jarFileName() {
        XCTAssertEqual(AppConstants.AuthlibInjector.jarFileName, "authlib-injector-1.2.7.jar")
    }

    func testAuthlibInjector_agentArgument() {
        let arg = AppConstants.AuthlibInjector.agentArgument(serverApiRoot: "https://littleskin.cn")
        XCTAssertTrue(arg.hasPrefix("-javaagent:"))
        XCTAssertTrue(arg.contains("authlib-injector-1.2.7.jar"))
        XCTAssertTrue(arg.contains("https://littleskin.cn"))
    }

    func testGameLoader_allCases() {
        XCTAssertEqual(GameLoader.allCases.count, 5)
    }

    func testGameLoader_displayName() {
        XCTAssertEqual(GameLoader.vanilla.displayName, "vanilla")
        XCTAssertEqual(GameLoader.fabric.displayName, "fabric")
        XCTAssertEqual(GameLoader.forge.displayName, "forge")
        XCTAssertEqual(GameLoader.neoforge.displayName, "neoforge")
        XCTAssertEqual(GameLoader.quilt.displayName, "quilt")
    }

    func testGameLoader_id() {
        XCTAssertEqual(GameLoader.vanilla.id, "vanilla")
        XCTAssertEqual(GameLoader.fabric.id, "fabric")
        XCTAssertEqual(GameLoader.forge.id, "forge")
    }

    func testModPackExportFormat_displayName() {
        XCTAssertEqual(ModPackExportFormat.modrinth.displayName, "Modrinth (.mrpack)")
        XCTAssertEqual(ModPackExportFormat.curseforge.displayName, "CurseForge (.zip)")
    }

    func testModPackExportFormat_fileExtension() {
        XCTAssertEqual(ModPackExportFormat.modrinth.fileExtension, "mrpack")
        XCTAssertEqual(ModPackExportFormat.curseforge.fileExtension, "zip")
    }

    func testBundle_appVersion() {
        let version = Bundle.main.appVersion
        XCTAssertFalse(version.isEmpty)
    }

    func testBundle_buildNumber() {
        let build = Bundle.main.buildNumber
        XCTAssertFalse(build.isEmpty)
    }

    func testBundle_fullVersion() {
        let fullVersion = Bundle.main.fullVersion
        XCTAssertTrue(fullVersion.contains("-"))
    }

    func testBundle_appName() {
        let appName = Bundle.main.appName
        XCTAssertFalse(appName.isEmpty)
    }

    func testBundle_identifier() {
        let identifier = Bundle.main.identifier
        XCTAssertFalse(identifier.isEmpty)
    }

    func testBundle_appCategory() {
        let category = Bundle.main.appCategory
        XCTAssertFalse(category.isEmpty)
    }
}
