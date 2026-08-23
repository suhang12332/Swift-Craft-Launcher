//
//  SwiftCraftLauncherAppCommands.swift
//  MainFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

// Custom menu commands for the app, including update checks, help links, and community resources.

import SwiftUI

struct SwiftCraftLauncherAppCommands: Commands {
    @CommandsBuilder var body: some Commands {
        if DIContainer.shared.system.sparkleUpdateService.updateAvailable {
            CommandMenu(String(format: "menu.update.released.title".localized(), DIContainer.shared.system.sparkleUpdateService.versionString)) {
                Link(
                    "menu.view.release.details".localized(),
                    destination: URLConfig.API.GitHub.releaseTag(version: DIContainer.shared.system.sparkleUpdateService.versionString),
                )
            }
        }

        CommandGroup(after: .appInfo) {
            Button("menu.check.updates".localized()) {
                DIContainer.shared.system.sparkleUpdateService.checkForUpdatesWithUI()
            }
            .keyboardShortcut("u", modifiers: [.command, .shift])
        }

        CommandGroup(after: .newItem) {
            Button("settings.game.clear_cache.label".localized()) {
                Task.detached(priority: .utility) {
                    DIContainer.shared.core.modCacheManager.clearLocalSilently()
                }
            }
        }

        CommandGroup(after: .help) {
            Divider()

            Link("GitHub", destination: URLConfig.API.GitHub.repositoryURL())
            Link("menu.community.website".localized(), destination: URLConfig.API.Community.website())

            Menu("menu.community".localized()) {
                Link("menu.community.discussions".localized(), destination: URLConfig.API.Community.discussions())
                Link("menu.community.discord".localized(), destination: URLConfig.API.Community.discord())
                Link("menu.community.qq".localized(), destination: URLConfig.API.Community.qq())
            }

            Link("menu.community.report.issue".localized(), destination: URLConfig.API.Community.issues())

            Button("about.contributors".localized()) {
                DIContainer.shared.ui.windowManager.openWindow(id: .contributors)
            }
            .keyboardShortcut("c", modifiers: [.command, .shift])

            Button("about.acknowledgements".localized()) {
                DIContainer.shared.ui.windowManager.openWindow(id: .acknowledgements)
            }
            .keyboardShortcut("a", modifiers: [.command, .shift])

            Link("license.view".localized(), destination: URLConfig.API.GitHub.license())
                .keyboardShortcut("l", modifiers: [.command, .option])

            Divider()

            Link("menu.ai.documentation".localized(), destination: URLConfig.API.Community.aiDocumentation())

            Button("ai.assistant.title".localized()) {
                DIContainer.shared.ui.aiChatManager.openChatWindow()
            }
            .keyboardShortcut("i", modifiers: [.command, .shift])
        }

        CommandGroup(replacing: .saveItem) { }
    }
}
