//
//  ModPackFailedResourcesView.swift
//  ModPackFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import SwiftUI

/// Payload used to open the failed modpack resources auxiliary window.
struct ModPackFailedResourcesWindowPayload {
    let failedResources: [FailedModPackResource]
    let onResourceHandled: (FailedModPackResource) -> Void
    let onAllHandled: () -> Void
    let onAbort: () -> Void
}

/// A view that walks through failed modpack resources one at a time, showing the install UI for each.
struct ModPackFailedResourcesView: View {
    let failedResources: [FailedModPackResource]
    @Binding var isPresented: Bool
    let onResourceHandled: (FailedModPackResource) -> Void
    let onAllHandled: () -> Void
    let onAbort: () -> Void

    @State private var remainingResources: [FailedModPackResource]

    init(
        failedResources: [FailedModPackResource],
        isPresented: Binding<Bool>,
        onResourceHandled: @escaping (FailedModPackResource) -> Void,
        onAllHandled: @escaping () -> Void,
        onAbort: @escaping () -> Void,
    ) {
        self.failedResources = failedResources
        _isPresented = isPresented
        self.onResourceHandled = onResourceHandled
        self.onAllHandled = onAllHandled
        self.onAbort = onAbort
        _remainingResources = State(initialValue: failedResources)
    }

    var body: some View {
        Group {
            if let current = remainingResources.first {
                FailedResourceInstallSection(
                    resource: current,
                    onSkip: {
                        handleHandled(current)
                    },
                    onDownloadSuccess: { _, _ in
                        handleHandled(current)
                    },
                )
                .id(current.id)
            }
        }
        .onDisappear {
            if !remainingResources.isEmpty {
                onAbort()
            }
        }
    }

    private func handleHandled(_ resource: FailedModPackResource) {
        remainingResources.removeFirst()
        onResourceHandled(resource)
        if remainingResources.isEmpty {
            onAllHandled()
            isPresented = false
        }
    }
}

/// Shows the shared resource install body and a dedicated footer for a single failed resource.
private struct FailedResourceInstallSection: View {
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

/// Dedicated footer for the failed resources window: skip and download the current resource only.
private struct FailedResourceInstallFooter: View {
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
