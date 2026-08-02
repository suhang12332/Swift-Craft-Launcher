//
//  MainView+Sheets.swift
//  MainFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import SwiftUI

/// Presents the mod pack import sheet when triggered by URL scheme.
struct ModPackImportSheetModifier: ViewModifier {
    @Environment(DIContainer.self)
    private var container

    func body(content: Content) -> some View {
        content.sheet(
            isPresented: Binding(
                get: { container.ui.openURLModPackImportPresenter.showImportSheet },
                set: { container.ui.openURLModPackImportPresenter.showImportSheet = $0 },
            ),
            onDismiss: { container.ui.openURLModPackImportPresenter.clear() },
            content: {
                if let file = container.ui.openURLModPackImportPresenter.preselectedTempFile {
                    GameFormView(initialMode: GameFormMode.modPackImport(file: file, shouldProcess: true))
                        .presentationBackgroundInteraction(.automatic)
                }
            },
        )
    }
}

extension View {
    func modPackImportSheet() -> some View {
        modifier(ModPackImportSheetModifier())
    }
}
