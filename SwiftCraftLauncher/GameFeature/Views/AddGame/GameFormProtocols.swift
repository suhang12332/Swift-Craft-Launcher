//
//  GameFormProtocols.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

/// Protocols and configuration types for game form state management.
import SwiftUI

@MainActor
protocol GameFormStateProtocol: ObservableObject {
    var isDownloading: Bool { get set }
    var isFormValid: Bool { get set }
    var triggerConfirm: Bool { get set }

    func handleCancel()
    func handleConfirm()
    func updateParentState()
}

/// Provides access to download progress state.
protocol DownloadProgressProvider {
    var gameSetupService: GameSetupUtil { get }
    var shouldShowProgress: Bool { get }
}

/// Provides form validation state for game creation.
protocol FormValidationProvider {
    var gameNameValidator: GameNameValidator { get }
    var isFormValid: Bool { get }
}

/// Action callbacks for game form confirm and cancel operations.
struct GameFormActions {
    let onCancel: () -> Void
    let onConfirm: () -> Void
}

/// Configuration bindings and actions for a game form.
struct GameFormConfiguration {
    let isDownloading: Binding<Bool>
    let isFormValid: Binding<Bool>
    let triggerConfirm: Binding<Bool>
    let triggerCancel: Binding<Bool>
    let actions: GameFormActions

    init(
        isDownloading: Binding<Bool>,
        isFormValid: Binding<Bool>,
        triggerConfirm: Binding<Bool>,
        triggerCancel: Binding<Bool>,
        onCancel: @escaping () -> Void,
        onConfirm: @escaping () -> Void
    ) {
        self.isDownloading = isDownloading
        self.isFormValid = isFormValid
        self.triggerConfirm = triggerConfirm
        self.triggerCancel = triggerCancel
        self.actions = GameFormActions(onCancel: onCancel, onConfirm: onConfirm)
    }
}
