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
    var onDownloadSuccess: ((String?, String?) -> Void)?

    @Environment(GameRepository.self)
    private var gameRepository

    @State private var viewModel: GameResourceInstallSheetViewModel

    init(
        resource: FailedModPackResource,
        onSkip: @escaping () -> Void,
        onDownloadSuccess: ((String?, String?) -> Void)?,
    ) {
        self.resource = resource
        self.onSkip = onSkip
        self.onDownloadSuccess = onDownloadSuccess
        _viewModel = State(
            wrappedValue: GameResourceInstallSheetViewModel(
                project: ModrinthProject.from(detail: resource.projectDetail),
                resourceType: resource.resourceType,
                gameInfo: resource.gameInfo,
                isUpdateMode: false,
            ),
        )
    }

    var body: some View {
        VStack(spacing: 18) {
            ModrinthProjectTitleView(
                projectDetail: resource.projectDetail,
            )
            VersionPickerForSheet(
                project: viewModel.project,
                resourceType: viewModel.resourceType,
                selectedGame: .constant(viewModel.gameInfo),
                selectedVersion: $viewModel.selectedVersion,
                availableVersions: $viewModel.availableVersions,
                mainVersionId: $viewModel.mainVersionId,
            ) { version in
                viewModel.onVersionChanged(version)
            }
            FailedResourceInstallFooter(
                projectDetail: resource.projectDetail,
                viewModel: viewModel,
                onSkip: onSkip,
                onDownloadSuccess: onDownloadSuccess,
            )
        }
        .padding()
        .padding(.horizontal)

        .onAppear {
            viewModel.setDependencies(gameRepository: gameRepository)
        }
        .onDisappear {
            viewModel.cleanup()
        }
    }
}
