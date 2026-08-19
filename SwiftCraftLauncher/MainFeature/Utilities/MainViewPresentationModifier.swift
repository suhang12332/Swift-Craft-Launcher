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
            .deleteGameConfirmationDialog(
                gamePendingDeletion: $gameDialogsPresenter.gamePendingDeletion,
                detailState: detailState,
            )
            .authlibInjectorMissingAlert(container)
            .memoryPressureAlert(container)
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
