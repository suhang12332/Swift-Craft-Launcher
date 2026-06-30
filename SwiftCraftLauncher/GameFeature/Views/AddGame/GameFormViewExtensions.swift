//
//  GameFormViewExtensions.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

/// View extensions for game form state listening and common error handling.
import SwiftUI

extension View {
    /// A modifier that observes game form state changes and triggers parent updates.
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
