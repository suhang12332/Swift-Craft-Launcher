//
//  SwiftCraftLauncherAppCommands.swift
//  Swift Craft Launcher
//

import SwiftUI

struct SwiftCraftLauncherAppCommands: Commands {
    let sparkleUpdateService: SparkleUpdateService
    let windowManager: WindowManager
    let aiChatManager: AIChatManager

    @CommandsBuilder
    var body: some Commands {
        if sparkleUpdateService.updateAvailable {
            CommandMenu(String(format: "menu.update.released.title".localized(), sparkleUpdateService.versionString)) {
                Link(
                    "menu.view.release.details".localized(),
                    destination: URLConfig.API.GitHub.releaseTag(version: sparkleUpdateService.versionString)
                )
            }
        }

        CommandGroup(after: .appInfo) {
            Button("menu.check.updates".localized()) {
                sparkleUpdateService.checkForUpdatesWithUI()
            }
            .keyboardShortcut("u", modifiers: [.command, .shift])
        }

        CommandGroup(after: .help) {
            Button("menu.open.log".localized()) {
                Logger.shared.openLogFile()
            }
            .keyboardShortcut("l", modifiers: [.command, .shift])

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
                windowManager.openWindow(id: .contributors)
            }
            .keyboardShortcut("c", modifiers: [.command, .shift])

            Button("about.acknowledgements".localized()) {
                windowManager.openWindow(id: .acknowledgements)
            }
            .keyboardShortcut("a", modifiers: [.command, .shift])

            Link("license.view".localized(), destination: URLConfig.API.GitHub.license())
                .keyboardShortcut("l", modifiers: [.command, .option])

            Divider()

            Button("ai.assistant.title".localized()) {
                aiChatManager.openChatWindow()
            }
            .keyboardShortcut("i", modifiers: [.command, .shift])
        }

        CommandGroup(replacing: .newItem) { }
        CommandGroup(replacing: .saveItem) { }
    }
}
