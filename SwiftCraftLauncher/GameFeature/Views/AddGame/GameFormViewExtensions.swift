//
//  GameFormViewExtensions.swift
//  SwiftCraftLauncher
//
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
    func handleFileAccessError(_ error: Error, context: String) {
        let globalError = GlobalError.fileSystem(
            chineseMessage: "无法访问文件: \(context)",
            i18nKey: "error.filesystem.file_access_failed",
            level: .notification
        )
        handleNonCriticalError(globalError, message: "error.file.access.failed".localized())
    }

    func handleFileReadError(_ error: Error, context: String) {
        let globalError = GlobalError.fileSystem(
            chineseMessage: "无法读取文件: \(context)",
            i18nKey: "error.filesystem.file_read_failed",
            level: .notification
        )
        handleNonCriticalError(globalError, message: "error.file.read.failed".localized())
    }
}
