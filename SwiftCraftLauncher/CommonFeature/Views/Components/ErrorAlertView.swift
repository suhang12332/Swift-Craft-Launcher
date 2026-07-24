//
//  ErrorAlertView.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import SwiftUI

/// A view modifier that presents error alerts from the global error handler.
struct ErrorAlertModifier: ViewModifier {
    @State private var errorHandler: GlobalErrorHandler
    private let source: ErrorSource

    init(errorHandler: GlobalErrorHandler, source: ErrorSource = .main) {
        _errorHandler = State(wrappedValue: errorHandler)
        self.source = source
    }

    func body(content: Content) -> some View {
        let isMatchingError = errorHandler.currentError != nil
            && errorHandler.currentError?.level == .popup
            && errorHandler.currentError?.source == source

        content
            .alert(
                errorHandler.currentError?.notificationTitle ?? "",
                isPresented: .constant(isMatchingError),
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
    /// Adds error alert handling to the view, scoped to the given source.
    func errorAlert(
        _ errorHandler: GlobalErrorHandler,
        source: ErrorSource = .main,
    ) -> some View {
        modifier(ErrorAlertModifier(errorHandler: errorHandler, source: source))
    }
}
