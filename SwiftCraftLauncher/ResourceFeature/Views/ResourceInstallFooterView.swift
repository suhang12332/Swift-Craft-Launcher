//
//  ResourceInstallFooterView.swift
//  ResourceFeature
//
//  © 2025 Swift Craft Launcher Team. All rights reserved.
//

import SwiftUI

/// Shared footer for installing a resource into a game.
///
/// Used by both the global resource sheet (game chosen by the user) and the
/// game install sheet (game fixed by the caller).
struct ResourceInstallFooterView: View {
    let projectDetail: ModrinthProjectDetail?
    let viewModel: ResourceInstallViewModel
    @Binding var isPresented: Bool

    var body: some View {
        if projectDetail != nil, viewModel.hasCompatibleGames {
            HStack {
                Button("common.close".localized()) { isPresented = false }
                Spacer()
                actionButton
            }
        } else {
            HStack {
                Spacer()
                Button("common.close".localized()) { isPresented = false }
            }
        }
    }

    @ViewBuilder private var actionButton: some View {
        if viewModel.resourceType == ResourceType.minecraftJavaServer.rawValue {
            if viewModel.selectedGame != nil {
                installButton(titleKey: "saveinfo.server.add") {
                    viewModel.addServerResource(projectDetail: projectDetail) {
                        isPresented = false
                    }
                }
            }
        } else if viewModel.isLoadingVersions || viewModel.selectedVersion != nil {
            installButton(titleKey: "global_resource.download") {
                if viewModel.resourceType == ResourceType.mod.rawValue, !viewModel.isUpdateMode {
                    viewModel.installModWithDependencies {
                        isPresented = false
                    }
                } else {
                    viewModel.installSingleResource {
                        isPresented = false
                    }
                }
            }
        } else if viewModel.resolvedGame != nil {
            Button("global_resource.no_version_available".localized()) { }
                .disabled(true)
        }
    }

    private func installButton(titleKey: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            if viewModel.isInstallLoading {
                ProgressView().controlSize(.small)
            } else {
                Text(titleKey.localized())
            }
        }
        .disabled(viewModel.isInstallLoading)
        .keyboardShortcut(.defaultAction)
    }
}
