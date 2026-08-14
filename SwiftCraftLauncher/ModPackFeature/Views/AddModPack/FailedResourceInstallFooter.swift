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
    var viewModel: GameResourceInstallSheetViewModel
    var onSkip: () -> Void
    var onDownloadSuccess: ((String?, String?) -> Void)?

    var body: some View {
        HStack {
            Button("common.skip".localized()) { onSkip() }
            Spacer()
            if projectDetail != nil, viewModel.selectedVersion != nil {
                Button {
                    viewModel.downloadResource(
                        onSuccess: { fileName, hash in
                            onDownloadSuccess?(fileName, hash)
                        },
                        dismiss: {},
                    )
                } label: {
                    if viewModel.isDownloadingAll {
                        ProgressView().controlSize(.small)
                    } else {
                        Text("global_resource.download".localized())
                    }
                }
                .disabled(viewModel.isDownloadingAll)
                .keyboardShortcut(.defaultAction)
            }
        }
    }
}
