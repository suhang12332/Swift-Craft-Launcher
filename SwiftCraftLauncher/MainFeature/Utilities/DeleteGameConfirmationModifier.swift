//
//  DeleteGameConfirmationModifier.swift
//  MainFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import SwiftUI

/// Confirmation dialog for deleting a game, shared across sidebar and toolbar entry points.
struct DeleteGameConfirmationModifier: ViewModifier {
    @Environment(DIContainer.self)
    private var container
    @Binding var gamePendingDeletion: GameVersionInfo?
    var detailState: ResourceDetailState

    @Environment(GameRepository.self)
    private var gameRepository

    init(
        gamePendingDeletion: Binding<GameVersionInfo?>,
        detailState: ResourceDetailState,
    ) {
        _gamePendingDeletion = gamePendingDeletion
        self.detailState = detailState
    }

    private var isDialogPresented: Binding<Bool> {
        Binding(
            get: { gamePendingDeletion != nil },
            set: { if !$0 { gamePendingDeletion = nil } },
        )
    }

    func body(content: Content) -> some View {
        content
            .confirmationDialog(
                "delete.title".localized(),
                isPresented: isDialogPresented,
                titleVisibility: .visible,
            ) {
                Button("common.delete".localized(), role: .destructive) {
                    if let game = gamePendingDeletion {
                        container.core.gameActionManager.deleteGame(
                            game: game,
                            gameRepository: gameRepository,
                            selectedItem: detailState.selectedItemBinding,
                            gameType: detailState.gameTypeBinding,
                        )
                        gamePendingDeletion = nil
                    }
                }
                .keyboardShortcut(.defaultAction)
                Button("common.cancel".localized(), role: .cancel) { }
            } message: {
                if let game = gamePendingDeletion {
                    Text(String(format: "delete.game.confirm".localized(), game.gameName))
                }
            }
    }
}

extension View {
    func deleteGameConfirmationDialog(
        gamePendingDeletion: Binding<GameVersionInfo?>,
        detailState: ResourceDetailState,
    ) -> some View {
        modifier(
            DeleteGameConfirmationModifier(
                gamePendingDeletion: gamePendingDeletion,
                detailState: detailState,
            ),
        )
    }
}
