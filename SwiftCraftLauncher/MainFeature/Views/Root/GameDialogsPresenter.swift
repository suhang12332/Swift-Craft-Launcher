import Foundation
import SwiftUI

/// 主窗口级游戏相关浮层状态（整合包导出 sheet、删除确认对话框等），由 `MainView` 统一挂载 UI。
@MainActor
final class GameDialogsPresenter: ObservableObject {
    static let shared = GameDialogsPresenter()

    @Published var gameForExport: GameVersionInfo?
    @Published var gamePendingDeletion: GameVersionInfo?

    private init() {}

    func presentModPackExport(for game: GameVersionInfo) {
        gameForExport = game
    }

    func requestGameDeletion(of game: GameVersionInfo) {
        gamePendingDeletion = game
    }
}
