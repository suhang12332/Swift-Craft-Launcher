//
//  TouchBarSupport.swift
//  MainFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import AppKit
import SwiftUI

/// Attaches the app-specific Touch Bar to the window that hosts the modified view.
extension View {
    func touchBarSupport() -> some View {
        background(TouchBarInstaller())
    }
}

/// A zero-size AppKit view that reports when it moves into a window.
private final class TouchBarAttachmentView: NSView {
    var onWindowChanged: ((NSWindow) -> Void)?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if let window {
            onWindowChanged?(window)
        }
    }
}

/// A button with a fixed minimum width whose content hugging is low, so the
/// Touch Bar distributes the remaining strip width evenly between all instance
/// buttons instead of sizing each by its title.
final class TouchBarInstanceButton: NSButton {
    var minimumWidth: CGFloat = 52

    override var intrinsicContentSize: NSSize {
        var size = super.intrinsicContentSize
        size.width = max(size.width, minimumWidth)
        return size
    }
}

/// Installs and keeps the launcher Touch Bar in sync with SwiftUI state.
private struct TouchBarInstaller: NSViewRepresentable {
    @Environment(DIContainer.self)
    private var container
    @Environment(GameRepository.self)
    private var gameRepository
    @Environment(GameLaunchUseCase.self)
    private var gameLaunchUseCase
    @Environment(PlayerListViewModel.self)
    private var playerListViewModel
    @Environment(\.openSettings)
    private var openSettings

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSView {
        let view = TouchBarAttachmentView()
        view.onWindowChanged = { [weak coordinator = context.coordinator] window in
            coordinator?.attach(to: window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.update(
            container: container,
            gameRepository: gameRepository,
            gameLaunchUseCase: gameLaunchUseCase,
            playerListViewModel: playerListViewModel,
        ) {
            openSettings()
        }
        if let window = nsView.window {
            context.coordinator.attach(to: window)
        }
    }
}

extension TouchBarInstaller {
    @MainActor
    final class Coordinator {
        let controller = TouchBarController()
        private var latestConfiguration: TouchBarConfiguration?

        func attach(to window: NSWindow) {
            controller.install(on: window)
            if let latestConfiguration {
                controller.update(with: latestConfiguration)
            }
        }

        func update(
            container: DIContainer,
            gameRepository: GameRepository,
            gameLaunchUseCase: GameLaunchUseCase,
            playerListViewModel: PlayerListViewModel,
            openSettings: @escaping @MainActor () -> Void,
        ) {
            let configuration = TouchBarConfiguration(
                container: container,
                gameRepository: gameRepository,
                gameLaunchUseCase: gameLaunchUseCase,
                playerListViewModel: playerListViewModel,
                openSettings: openSettings,
            )
            latestConfiguration = configuration
            controller.update(with: configuration)
        }
    }
}

/// The state and actions required to render the launcher Touch Bar.
struct TouchBarConfiguration {
    let container: DIContainer
    let gameRepository: GameRepository
    let gameLaunchUseCase: GameLaunchUseCase
    let playerListViewModel: PlayerListViewModel
    let openSettings: @MainActor () -> Void
}
