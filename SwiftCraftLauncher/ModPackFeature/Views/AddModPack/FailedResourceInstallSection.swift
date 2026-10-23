//
//  FailedResourceInstallSection.swift
//  ModPackFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import SwiftUI

/// Shows the shared resource install body and a dedicated footer for a single failed resource.
struct FailedResourceInstallSection: View {
    let resource: FailedModPackResource
    var onSkip: () -> Void

    @State private var viewModel: ResourceInstallViewModel

    init(
        resource: FailedModPackResource,
        onSkip: @escaping () -> Void,
        onDownloadSuccess: ((String?, String?) -> Void)?,
    ) {
        self.resource = resource
        self.onSkip = onSkip
        _viewModel = State(
            wrappedValue: ResourceInstallViewModel(
                project: ModrinthProject.from(detail: resource.projectDetail),
                resourceType: resource.resourceType,
                fixedGame: resource.gameInfo,
                configuration: .init(onSuccess: onDownloadSuccess),
            ),
        )
    }

    var body: some View {
        @Bindable var viewModel = viewModel
        return VStack(spacing: 18) {
            ModrinthProjectTitleView(
                projectDetail: resource.projectDetail,
            )
            VersionPickerForSheet(
                project: viewModel.project,
                resourceType: viewModel.resourceType,
                selectedGame: resource.gameInfo,
                selectedVersion: $viewModel.selectedVersion,
                availableVersions: $viewModel.availableVersions,
                isLoading: $viewModel.isLoadingVersions,
                mainVersionId: $viewModel.mainVersionId,
            ) { version in
                viewModel.onVersionChanged(version)
            }
            FailedResourceInstallFooter(
                projectDetail: resource.projectDetail,
                viewModel: viewModel,
                onSkip: onSkip,
            )
        }
        .padding()
        .padding(.horizontal)
        .onDisappear {
            viewModel.cleanup()
        }
    }
}
