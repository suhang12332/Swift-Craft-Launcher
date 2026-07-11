//
//  MainViewPresentationModifier.swift
//  MainFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import SwiftUI

/// Attaches main-window presentation layers including export sheets, deletion confirmation, and startup announcement.
struct MainViewPresentationModifier: ViewModifier {
    @StateObject private var gameDialogsPresenter: GameDialogsPresenter
    @StateObject private var container: DIContainer
    @ObservedObject var detailState: ResourceDetailState

    @StateObject private var startupAnnouncementViewModel = StartupAnnouncementViewModel()
    @State private var showStartupInfo = false
    @State private var hasPresentedStartupInfo = false

    init(
        detailState: ResourceDetailState,
        gameDialogsPresenter: GameDialogsPresenter,
        container: DIContainer,
    ) {
        self.detailState = detailState
        _gameDialogsPresenter = StateObject(wrappedValue: gameDialogsPresenter)
        _container = StateObject(wrappedValue: container)
    }

    func body(content: Content) -> some View {
        content
            .sheet(item: $gameDialogsPresenter.gameForExport) { game in
                ModPackExportSheet(gameInfo: game)
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
