//
//  GameFormProtocols.swift
//  SwiftCraftLauncher
//
//  Created by AI Assistant on 2025/1/27.
//

import SwiftUI

// MARK: - Game Form State Protocol
@MainActor
protocol GameFormStateProtocol: ObservableObject {
    var isDownloading: Bool { get set }
    var isFormValid: Bool { get set }
    var triggerConfirm: Bool { get set }

    func handleCancel()
    func handleConfirm()
    func updateParentState()
}

// MARK: - Download Progress Provider Protocol
protocol DownloadProgressProvider {
    var gameSetupService: GameSetupUtil { get }
    var shouldShowProgress: Bool { get }
}

// MARK: - Form Validation Provider Protocol
protocol FormValidationProvider {
    var gameNameValidator: GameNameValidator { get }
    var isFormValid: Bool { get }
}

// MARK: - Game Form Actions
struct GameFormActions {
    let onCancel: () -> Void
    let onConfirm: () -> Void
}

// MARK: - Game Form Configuration
struct GameFormConfiguration {
    let isDownloading: Binding<Bool>
    let isFormValid: Binding<Bool>
    let triggerConfirm: Binding<Bool>
    let actions: GameFormActions

    init(
        isDownloading: Binding<Bool>,
        isFormValid: Binding<Bool>,
        triggerConfirm: Binding<Bool>,
        onCancel: @escaping () -> Void,
        onConfirm: @escaping () -> Void
    ) {
        self.isDownloading = isDownloading
        self.isFormValid = isFormValid
        self.triggerConfirm = triggerConfirm
        self.actions = GameFormActions(onCancel: onCancel, onConfirm: onConfirm)
    }
}
