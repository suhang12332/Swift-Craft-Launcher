//
//  GameFormViewExtensions.swift
//  SwiftCraftLauncher
//
//  Created by AI Assistant on 2025/1/27.
//

import SwiftUI

// MARK: - Game Form View Extensions
extension View {
    /// 通用的游戏表单状态监听修饰符
    func gameFormStateListeners<T: BaseGameFormViewModel>(
        viewModel: T,
        triggerConfirm: Binding<Bool>,
        triggerCancel: Binding<Bool>
    ) -> some View {
        self
            // 优化：仅在值实际变化时更新，减少不必要的视图更新
            .onChange(of: viewModel.gameNameValidator.gameName) { oldValue, newValue in
                if oldValue != newValue {
                    viewModel.updateParentState()
                }
            }
            .onChange(of: viewModel.gameNameValidator.isGameNameDuplicate) { oldValue, newValue in
                if oldValue != newValue {
                    viewModel.updateParentState()
                }
            }
            .onChange(of: viewModel.gameSetupService.downloadState.isDownloading) { oldValue, newValue in
                if oldValue != newValue {
                    viewModel.updateParentState()
                }
            }
            .onChange(of: triggerConfirm.wrappedValue) { _, newValue in
                if newValue {
                    viewModel.handleConfirm()
                    triggerConfirm.wrappedValue = false
                }
            }
            .onChange(of: triggerCancel.wrappedValue) { _, newValue in
                if newValue {
                    viewModel.handleCancel()
                    triggerCancel.wrappedValue = false
                }
            }
    }
}

// MARK: - Common Error Handling
extension BaseGameFormViewModel {
    /// 统一的文件访问错误处理
    func handleFileAccessError(_ error: Error, context: String) {
        let globalError = GlobalError.fileSystem(
            chineseMessage: "无法访问文件: \(context)",
            i18nKey: "error.filesystem.file_access_failed",
            level: .notification
        )
        handleNonCriticalError(globalError, message: "error.file.access.failed".localized())
    }

    /// 统一的文件读取错误处理
    func handleFileReadError(_ error: Error, context: String) {
        let globalError = GlobalError.fileSystem(
            chineseMessage: "无法读取文件: \(context)",
            i18nKey: "error.filesystem.file_read_failed",
            level: .notification
        )
        handleNonCriticalError(globalError, message: "error.file.read.failed".localized())
    }
}
