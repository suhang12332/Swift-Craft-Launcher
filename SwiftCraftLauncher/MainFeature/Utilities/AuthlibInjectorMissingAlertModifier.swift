//
//  AuthlibInjectorMissingAlertModifier.swift
//  MainFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import SwiftUI

/// Presents an alert when the authlib-injector is missing before game launch.
struct AuthlibInjectorMissingAlertModifier: ViewModifier {
    @State private var authlibInjectorMissingPresenter: AuthlibInjectorMissingPresenter

    init(
        authlibInjectorMissingPresenter: AuthlibInjectorMissingPresenter,
    ) {
        self.authlibInjectorMissingPresenter = authlibInjectorMissingPresenter
    }

    private var alertBinding: Binding<Bool> {
        Binding(
            get: { authlibInjectorMissingPresenter.isPresented },
            set: { newValue in
                if !newValue {
                    authlibInjectorMissingPresenter.dismissIfNeeded(as: .cancel)
                }
            },
        )
    }

    func body(content: Content) -> some View {
        content
            .alert(
                "game_launch.authlib_injector_missing.title".localized(),
                isPresented: alertBinding,
            ) {
                Button("common.continue".localized()) {
                    authlibInjectorMissingPresenter.resolve(.continueWithoutInjector)
                }
                Button("common.close".localized(), role: .cancel) {
                    authlibInjectorMissingPresenter.resolve(.cancel)
                }
            } message: {
                Text("game_launch.authlib_injector_missing.message".localized())
            }
    }
}

extension View {
    func authlibInjectorMissingAlert(
        _ container: DIContainer,
    ) -> some View {
        modifier(AuthlibInjectorMissingAlertModifier(
            authlibInjectorMissingPresenter: container.ui.authlibInjectorMissingPresenter,
        ))
    }
}
