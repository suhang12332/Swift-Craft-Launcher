//
//  DeleteGameConfirmationModifier.swift
//  SwiftCraftLauncher
//

import SwiftUI

/// 统一的「删除游戏」确认对话框（侧边栏、工具栏等入口共用）
struct DeleteGameConfirmationModifier: ViewModifier {
    @Binding var gamePendingDeletion: GameVersionInfo?

    @EnvironmentObject private var gameRepository: GameRepository
    @EnvironmentObject private var detailState: ResourceDetailState

    private var isDialogPresented: Binding<Bool> {
        Binding(
            get: { gamePendingDeletion != nil },
            set: { if !$0 { gamePendingDeletion = nil } }
        )
    }

    func body(content: Content) -> some View {
        content
            .confirmationDialog(
                "delete.title".localized(),
                isPresented: isDialogPresented,
                titleVisibility: .visible
            ) {
                Button("common.delete".localized(), role: .destructive) {
                    if let game = gamePendingDeletion {
                        GameActionManager.shared.deleteGame(
                            game: game,
                            gameRepository: gameRepository,
                            selectedItem: detailState.selectedItemBinding,
                            gameType: detailState.gameTypeBinding
                        )
                        gamePendingDeletion = nil
                    }
                }
                .keyboardShortcut(.defaultAction)
                Button("common.cancel".localized(), role: .cancel) {}
            } message: {
                if let game = gamePendingDeletion {
                    Text(String(format: "delete.game.confirm".localized(), game.gameName))
                }
            }
    }
}

extension View {
    func deleteGameConfirmationDialog(gamePendingDeletion: Binding<GameVersionInfo?>) -> some View {
        modifier(DeleteGameConfirmationModifier(gamePendingDeletion: gamePendingDeletion))
    }
}
