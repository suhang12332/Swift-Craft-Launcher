//
//  GameNameValidator.swift
//  SwiftCraftLauncher
//
//  Created by su on 2025/1/27.
//

import SwiftUI

// MARK: - GameNameValidator
@MainActor
class GameNameValidator: ObservableObject {
    @Published var gameName: String = ""
    @Published var isGameNameDuplicate: Bool = false

    private let gameSetupService: GameSetupUtil

    init(gameSetupService: GameSetupUtil) {
        self.gameSetupService = gameSetupService
    }

    /// 验证游戏名称是否重复
    func validateGameName() async {
        guard !gameName.isEmpty else {
            isGameNameDuplicate = false
            return
        }

        let isDuplicate = await gameSetupService.checkGameNameDuplicate(gameName)
        if isDuplicate != isGameNameDuplicate {
            isGameNameDuplicate = isDuplicate
        }
    }

    /// 设置默认游戏名称（仅在当前名称为空时设置）
    func setDefaultName(_ name: String) {
        if gameName.isEmpty {
            gameName = name
        }
    }

    /// 重置验证状态
    func reset() {
        gameName = ""
        isGameNameDuplicate = false
    }

    /// 检查表单是否有效
    var isFormValid: Bool {
        !gameName.isEmpty && !isGameNameDuplicate
    }
}
