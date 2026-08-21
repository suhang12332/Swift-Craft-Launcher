//
//  MainViewPresentationModifier.swift
//  MainFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import SwiftUI

/// Attaches main-window presentation layers including export sheets, deletion confirmation, and startup announcement.
struct MainViewPresentationModifier: ViewModifier {
    @State private var gameDialogsPresenter: GameDialogsPresenter
    @State private var container: DIContainer
    var detailState: ResourceDetailState

    @Environment(GameRepository.self)
    private var gameRepository

    @State private var memoryPressureAlertPresenter: MemoryPressureAlertPresenter
    @State private var authlibInjectorMissingPresenter: AuthlibInjectorMissingPresenter
    @State private var startupAnnouncementViewModel = StartupAnnouncementViewModel()
    @State private var showStartupInfo = false
    @State private var hasPresentedStartupInfo = false

    init(
        detailState: ResourceDetailState,
        gameDialogsPresenter: GameDialogsPresenter,
        container: DIContainer,
    ) {
        self.detailState = detailState
        self.gameDialogsPresenter = gameDialogsPresenter
        self.container = container
        _memoryPressureAlertPresenter = State(wrappedValue: container.ui.memoryPressureAlertPresenter)
        _authlibInjectorMissingPresenter = State(wrappedValue: container.ui.authlibInjectorMissingPresenter)
    }

    func body(content: Content) -> some View {
        @Bindable var gameDialogsPresenter = gameDialogsPresenter
        content
            .sheet(item: $gameDialogsPresenter.gameForExport) { game in
                ModPackExportSheet(gameInfo: game)
            }
            .sheet(item: $gameDialogsPresenter.gamePendingLoaderUpdate) { game in
                GameLoaderUpdateView(gameInfo: game)
                    .presentationBackgroundInteraction(.automatic)
            }
            .task {
                await startupAnnouncementViewModel.checkAnnouncementIfNeeded()
            }
            .onChange(of: startupAnnouncementViewModel.hasAnnouncement) { _, hasAnnouncement in
                guard
                    hasAnnouncement,
                    startupAnnouncementViewModel.announcementData != nil,
                    !hasPresentedStartupInfo
                else { return }
                hasPresentedStartupInfo = true
                showStartupInfo = true
            }
            .sheet(isPresented: $showStartupInfo) {
                StartupInfoSheetView(announcementData: startupAnnouncementViewModel.announcementData)
            }
            .deleteConfirmationDialog(
                pendingDeletion: $gameDialogsPresenter.gamePendingDeletion,
                title: "delete.title".localized(),
                message: { game in
                    String(format: "delete.game.confirm".localized(), game.gameName)
                },
                delete: { game in
                    container.core.gameActionManager.deleteGame(
                        game: game,
                        gameRepository: gameRepository,
                        selectedItem: detailState.selectedItemBinding,
                        gameType: detailState.gameTypeBinding,
                    )
                },
            )
            .presenterAlert(
                isPresented: memoryPressureAlertPresenter.asBinding(),
                title: "game_launch.memory_pressure.title".localized(),
                message: memoryPressureAlertPresenter.pressureLevel.localizedMessage,
                primaryTitle: "common.continue".localized(),
                primaryAction: { memoryPressureAlertPresenter.resolve(.continueAnyway) },
            )
            .presenterAlert(
                isPresented: authlibInjectorMissingPresenter.asBinding(),
                title: "game_launch.authlib_injector_missing.title".localized(),
                message: "game_launch.authlib_injector_missing.message".localized(),
                primaryTitle: "common.continue".localized(),
                primaryAction: { authlibInjectorMissingPresenter.resolve(.continueWithoutInjector) },
            )
    }
}

extension View {
    func mainViewPresentations(
        container: DIContainer,
        detailState: ResourceDetailState,
    ) -> some View {
        modifier(
            MainViewPresentationModifier(
                detailState: detailState,
                gameDialogsPresenter: container.ui.gameDialogsPresenter,
                container: container,
            ),
        )
    }
}
