//
//  LaunchCommandPreparerTests.swift
//  SwiftCraftLauncherTests
//
//  © 2025 Swift Craft Launcher Team. All rights reserved.
//

@testable import SwiftCraftLauncher
import XCTest

final class LaunchCommandPreparerTests: XCTestCase {
    func testPreparePreservesUnresolvedAssetPlaceholdersInSavedCommand() throws {
        var game = makeGame(xms: 1024, xmx: 4096)
        game.assetIndex = "1.8"
        game.launchCommand = [
            "-Xms${xms}M", "-Xmx${xmx}M",
            "net.minecraft.launchwrapper.Launch",
            "--assetsDir", "${assets_root}",
            "--assetIndex", "${assets_index_name}",
            "--username", "${auth_player_name}",
            "--tweakClass", "net.minecraftforge.fml.common.launcher.FMLTweaker",
        ]
        let credentials = LaunchCredentials(
            player: try Player(name: "Steve"),
            accessToken: "test-token",
            authlibAgentArgument: nil,
        )

        let result = LaunchCommandPreparer().prepare(
            command: game.launchCommand,
            game: game,
            credentials: credentials,
        )

        XCTAssertEqual(result, [
            "-Xms1024M", "-Xmx4096M",
            "net.minecraft.launchwrapper.Launch",
            "--assetsDir", "${assets_root}",
            "--assetIndex", "${assets_index_name}",
            "--username", "Steve",
            "--tweakClass", "net.minecraftforge.fml.common.launcher.FMLTweaker",
        ])
        XCTAssertEqual(game.launchCommand[4], "${assets_root}")
    }

    func testPreparePreservesResolvedAssetArgumentsWithSpaces() throws {
        let game = makeGame()
        let command = [
            "--assetsDir", "/custom/Application Support/Minecraft Assets",
            "--assetIndex", "custom-index",
        ]
        let credentials = LaunchCredentials(
            player: try Player(name: "Steve"),
            accessToken: "",
            authlibAgentArgument: nil,
        )

        let result = LaunchCommandPreparer().prepare(
            command: command,
            game: game,
            credentials: credentials,
        )

        XCTAssertEqual(result, command)
    }

    func testPrepareReplacesAuthParametersAndPrependsAgent() throws {
        let game = makeGame()
        let player = try Player(name: "Steve", uuid: "player-id")
        let credentials = LaunchCredentials(
            player: player,
            accessToken: "access-token",
            authlibAgentArgument: "-javaagent:authlib.jar",
        )
        let command = [
            "--username", "${auth_player_name}",
            "--uuid", "${auth_uuid}",
            "--accessToken", "${auth_access_token}",
            "--xuid", "${auth_xuid}",
        ]

        let result = LaunchCommandPreparer().prepare(
            command: command,
            game: game,
            credentials: credentials,
        )

        XCTAssertEqual(result.first, "-javaagent:authlib.jar")
        let usernameIndex = try XCTUnwrap(result.firstIndex(of: "--username"))
        let uuidIndex = try XCTUnwrap(result.firstIndex(of: "--uuid"))
        let accessTokenIndex = try XCTUnwrap(result.firstIndex(of: "--accessToken"))
        XCTAssertEqual(result[usernameIndex + 1], "Steve")
        XCTAssertEqual(result[uuidIndex + 1], "player-id")
        XCTAssertEqual(result[accessTokenIndex + 1], "access-token")
    }

    func testPrepareReplacesGameParametersAndDeduplicatesJvmArguments() throws {
        let game = makeGame(xms: 1024, xmx: 4096, jvmArguments: "-Dfoo=bar -Dfoo=bar -Dbaz=qux")
        let player = try Player(name: "Steve")
        let credentials = LaunchCredentials(
            player: player,
            accessToken: "",
            authlibAgentArgument: nil,
        )
        let command = [
            "-Xms${xms}M",
            "-Xmx${xmx}M",
            "${game_directory}",
            "${user_properties}",
        ]

        let result = LaunchCommandPreparer().prepare(
            command: command,
            game: game,
            credentials: credentials,
        )

        XCTAssertEqual(result, [
            "-Dfoo=bar",
            "-Dbaz=qux",
            "-Xms1024M",
            "-Xmx4096M",
            AppPaths.profileDirectory(gameName: game.gameName).path,
            "${user_properties}",
        ])
    }

    private func makeGame(
        xms: Int = 0,
        xmx: Int = 0,
        jvmArguments: String = "",
    ) -> GameVersionInfo {
        GameVersionInfo(
            gameName: "TestGame",
            gameIcon: "",
            gameVersion: "1.20.1",
            assetIndex: "17",
            modLoader: "vanilla",
            jvmArguments: jvmArguments,
            xms: xms,
            xmx: xmx,
        )
    }
}
