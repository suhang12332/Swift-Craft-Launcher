//
//  ErrorAlertView.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import SwiftUI

/// A view modifier that presents error alerts from the global error handler.
struct ErrorAlertModifier: ViewModifier {
    @StateObject private var errorHandler: GlobalErrorHandler

    init(errorHandler: GlobalErrorHandler) {
        _errorHandler = StateObject(wrappedValue: errorHandler)
    }

    func body(content: Content) -> some View {
        content
            .alert(
                errorHandler.currentError?.notificationTitle ?? "",
                isPresented: .constant(errorHandler.currentError != nil && errorHandler.currentError?.level == .popup),
            ) {
                Button("common.close".localized()) {
                    errorHandler.clearCurrentError()
                }
            } message: {
                if let error = errorHandler.currentError {
                    Text(error.localizedDescription)
                }
            }
    }
}

extension View {
    /// Adds error alert handling to the view.
    func errorAlert(
        _ errorHandler: GlobalErrorHandler,
    ) -> some View {
        modifier(ErrorAlertModifier(errorHandler: errorHandler))
    }
}
