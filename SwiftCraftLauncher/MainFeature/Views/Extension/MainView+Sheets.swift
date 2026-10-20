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
    @State private var showRegionBlockedAlert = false

    func body(content: Content) -> some View {
        content
            .sheet(
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
            .onChange(of: container.ui.openURLModPackImportPresenter.showImportSheet) { _, newValue in
                guard newValue else { return }
                Task { @MainActor in
                    if await CNRegionGate.isBlocked() {
                        container.ui.openURLModPackImportPresenter.showImportSheet = false
                        container.ui.openURLModPackImportPresenter.clear()
                        showRegionBlockedAlert = true
                    }
                }
            }
            .alert(
                "region.block.title".localized(),
                isPresented: $showRegionBlockedAlert,
            ) {
                Button("common.confirm".localized(), role: .cancel) { }
            } message: {
                Text("region.block.message".localized())
            }
    }
}

extension View {
    func modPackImportSheet() -> some View {
        modifier(ModPackImportSheetModifier())
    }
}
