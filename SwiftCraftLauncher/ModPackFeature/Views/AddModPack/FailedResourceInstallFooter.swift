//
//  FailedResourceInstallFooter.swift
//  ModPackFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import SwiftUI

/// Dedicated footer for the failed resources window: skip and download the current resource only.
struct FailedResourceInstallFooter: View {
    let projectDetail: ModrinthProjectDetail?
    let viewModel: ResourceInstallViewModel
    var onSkip: () -> Void

    var body: some View {
        HStack {
            Button("common.skip".localized()) { onSkip() }
            Spacer()
            if projectDetail != nil,
               viewModel.isLoadingVersions || viewModel.selectedVersion != nil {
                Button {
                    viewModel.installSingleResource { }
                } label: {
                    if viewModel.isInstallLoading {
                        ProgressView().controlSize(.small)
                    } else {
                        Text("global_resource.download".localized())
                    }
                }
                .disabled(viewModel.isInstallLoading)
                .keyboardShortcut(.defaultAction)
            }
        }
    }
}
