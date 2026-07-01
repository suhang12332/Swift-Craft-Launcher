//
//  GameFormViewExtensions.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

// View extensions for game form state listening and common error handling.
import SwiftUI

extension View {
    /// A modifier that observes game form state changes and triggers parent updates.
    func gameFormStateListeners(
        viewModel: some BaseGameFormViewModel,
        triggerConfirm: Binding<Bool>,
        triggerCancel: Binding<Bool>,
    ) -> some View {
        onChange(of: viewModel.gameNameValidator.gameName) { oldValue, newValue in
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
    func handleFileAccessError(_: Error, context _: String) {
        let globalError = GlobalError.fileSystem(
            i18nKey: "error.filesystem.file_access_failed",
            level: .notification,
        )
        handleNonCriticalError(globalError, message: "error.file.access.failed".localized())
    }

    func handleFileReadError(_: Error, context _: String) {
        let globalError = GlobalError.fileSystem(
            i18nKey: "error.filesystem.file_read_failed",
            level: .notification,
        )
        handleNonCriticalError(globalError, message: "error.file.read.failed".localized())
    }
}
