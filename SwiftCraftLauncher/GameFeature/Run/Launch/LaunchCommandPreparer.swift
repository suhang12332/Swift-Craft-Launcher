//
//  LaunchCommandPreparer.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Applies authenticated player data and runtime settings to a prebuilt launch command.
struct LaunchCommandPreparer {
    func prepare(
        command: [String],
        game: GameVersionInfo,
        credentials: LaunchCredentials,
    ) -> [String] {
        var command = command
        if let agentArgument = credentials.authlibAgentArgument {
            command.insert(agentArgument, at: 0)
        }

        let replacements: [String: String] = [
            "${auth_player_name}": credentials.player.name,
            "${auth_uuid}": credentials.player.id,
            "${auth_access_token}": credentials.accessToken,
            "${auth_xuid}": credentials.player.authXuid,
        ]
        let authenticatedCommand = command.map { argument in
            replacements.reduce(into: argument) { result, pair in
                result = result.replacingOccurrences(of: pair.key, with: pair.value)
            }
        }

        return applyGameParameters(to: authenticatedCommand, game: game)
    }

    private func applyGameParameters(to command: [String], game: GameVersionInfo) -> [String] {
        let settings = DIContainer.shared.ui.gameSettingsManager
        let xms = game.xms > 0 ? game.xms : settings.globalXms
        let xmx = game.xmx > 0 ? game.xmx : settings.globalXmx

        let replacements: [String: String] = [
            "${xms}": "\(xms)",
            "${xmx}": "\(xmx)",
            "${game_directory}": AppPaths.profileDirectory(gameName: game.gameName).path,
        ]
        var replacedCommand = command.map { argument in
            replacements.reduce(into: argument) { result, pair in
                result = result.replacingOccurrences(of: pair.key, with: pair.value)
            }
        }

        if !game.jvmArguments.isEmpty {
            let advancedArguments = game.jvmArguments
                .components(separatedBy: " ")
                .filter { !$0.isEmpty }
            var seen = Set<String>()
            let uniqueArguments = advancedArguments.filter { argument in
                guard seen.insert(argument).inserted else { return false }
                return true
            }
            replacedCommand.insert(contentsOf: uniqueArguments, at: 0)
        }

        return replacedCommand
    }
}
