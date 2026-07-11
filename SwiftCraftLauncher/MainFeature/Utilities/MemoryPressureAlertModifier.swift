//
//  MemoryPressureAlertModifier.swift
//  MainFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import SwiftUI

/// Presents an alert when the system is under memory pressure before game launch.
struct MemoryPressureAlertModifier: ViewModifier {
    @StateObject private var memoryPressureAlertPresenter: MemoryPressureAlertPresenter

    init(
        memoryPressureAlertPresenter: MemoryPressureAlertPresenter,
    ) {
        _memoryPressureAlertPresenter = StateObject(wrappedValue: memoryPressureAlertPresenter)
    }

    private var alertBinding: Binding<Bool> {
        Binding(
            get: { memoryPressureAlertPresenter.isPresented },
            set: { newValue in
                if !newValue {
                    memoryPressureAlertPresenter.resolve(.cancel)
                }
            },
        )
    }

    func body(content: Content) -> some View {
        content
            .alert(
                "game_launch.memory_pressure.title".localized(),
                isPresented: alertBinding,
            ) {
                Button("common.continue".localized()) {
                    memoryPressureAlertPresenter.resolve(.continueAnyway)
                }
                Button("common.close".localized(), role: .cancel) {
                    memoryPressureAlertPresenter.resolve(.cancel)
                }
            } message: {
                Text(memoryPressureAlertPresenter.pressureLevel.localizedMessage)
            }
    }
}

extension View {
    func memoryPressureAlert(
        _ container: DIContainer,
    ) -> some View {
        modifier(MemoryPressureAlertModifier(
            memoryPressureAlertPresenter: container.ui.memoryPressureAlertPresenter,
        ))
    }
}
