//
//  PresenterAlertModifier.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import SwiftUI

/// Generic alert driven by a presenter's `isPresented` state, with configurable primary and cancel actions.
struct PresenterAlertModifier: ViewModifier {
    @Binding var isPresented: Bool
    var title: String
    var message: String
    var primaryTitle: String
    var primaryAction: () -> Void
    var cancelTitle: String
    var cancelAction: () -> Void

    func body(content: Content) -> some View {
        content
            .alert(
                title,
                isPresented: $isPresented,
            ) {
                Button(primaryTitle, action: primaryAction)
                Button(cancelTitle, role: .cancel, action: cancelAction)
            } message: {
                Text(message)
            }
    }
}

extension View {
    func presenterAlert(
        isPresented: Binding<Bool>,
        title: String,
        message: String,
        primaryTitle: String,
        primaryAction: @escaping () -> Void,
        cancelTitle: String = "common.close".localized(),
        cancelAction: @escaping () -> Void = { },
    ) -> some View {
        modifier(
            PresenterAlertModifier(
                isPresented: isPresented,
                title: title,
                message: message,
                primaryTitle: primaryTitle,
                primaryAction: primaryAction,
                cancelTitle: cancelTitle,
                cancelAction: cancelAction,
            ),
        )
    }
}
