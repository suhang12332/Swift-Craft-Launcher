import SwiftUI

struct DependencySheetView: View {
    @ObservedObject var viewModel: DependencySheetViewModel
    @Binding var isDownloadingAllDependencies: Bool
    @Binding var isDownloadingMainResourceOnly: Bool
    let projectDetail: ModrinthProjectDetail
    @StateObject private var actionViewModel: DependencySheetActionViewModel

    let onDownloadAll: () async -> Void
    let onDownloadMainOnly: () async -> Void

    init(
        viewModel: DependencySheetViewModel,
        isDownloadingAllDependencies: Binding<Bool>,
        isDownloadingMainResourceOnly: Binding<Bool>,
        projectDetail: ModrinthProjectDetail,
        onDownloadAll: @escaping () async -> Void,
        onDownloadMainOnly: @escaping () async -> Void
    ) {
        self.viewModel = viewModel
        self._isDownloadingAllDependencies = isDownloadingAllDependencies
        self._isDownloadingMainResourceOnly = isDownloadingMainResourceOnly
        self.projectDetail = projectDetail
        self.onDownloadAll = onDownloadAll
        self.onDownloadMainOnly = onDownloadMainOnly
        self._actionViewModel = StateObject(
            wrappedValue: DependencySheetActionViewModel(
                isDownloadingAllDependencies: isDownloadingAllDependencies,
                isDownloadingMainResourceOnly: isDownloadingMainResourceOnly
            )
        )
    }

    var body: some View {
        CommonSheetView(
            header: {
                Text("dependency.required_mods.title".localized())
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
            },
            body: {
                if viewModel.isLoadingDependencies {
                    ProgressView().frame(height: 100).controlSize(.small)
                } else {
                    ModrinthProjectTitleView(projectDetail: projectDetail)
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(viewModel.missingDependencies, id: \.id) { dep in
                            let versions =
                                viewModel.dependencyVersions[dep.id] ?? []
                            if !versions.isEmpty {
                                VStack(alignment: .leading) {
                                    HStack(alignment: .center) {
                                        Text(dep.title)
                                            .font(.headline)
                                        Spacer()
                                    }
                                    CommonMenuPicker(
                                        selection: Binding(
                                            get: {
                                                viewModel
                                                    .selectedDependencyVersion[
                                                        dep.id
                                                    ]
                                                    ?? (versions.first?.id ?? "")
                                            },
                                            set: {
                                                viewModel
                                                    .selectedDependencyVersion[
                                                        dep.id
                                                    ] = $0
                                            }
                                        )
                                    ) {
                                        Text("dependency.version.picker".localized())
                                    } content: {
                                        ForEach(versions, id: \.id) { v in
                                            Text(v.name).tag(v.id)
                                        }
                                    }
                                    .font(.subheadline)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                        }
                    }
                }
            },
            footer: {
                if viewModel.isLoadingDependencies {
                    HStack {
                        Spacer()
                        Button("common.close".localized()) {
                            viewModel.showDependenciesSheet = false
                        }
                    }
                } else if !viewModel.missingDependencies.isEmpty {
                    HStack {
                        Button("common.close".localized()) {
                            viewModel.showDependenciesSheet = false
                        }
                        Spacer()

                        let hasDownloading = viewModel.missingDependencies
                            .contains {
                                viewModel.dependencyDownloadStates[$0.id]
                                    == .downloading
                            }
                        Button {
                            actionViewModel.downloadMainOnly(onDownloadMainOnly: onDownloadMainOnly)
                        } label: {
                            if isDownloadingMainResourceOnly {
                                ProgressView().controlSize(.small)
                            } else {
                                Text(
                                    "global_resource.download_main_only"
                                        .localized()
                                )
                            }
                        }
                        .disabled(
                            isDownloadingAllDependencies
                                || isDownloadingMainResourceOnly
                        )
                        switch viewModel.overallDownloadState {
                        case .idle:
                            Button {
                                actionViewModel.downloadAll(onDownloadAll: onDownloadAll)
                            } label: {
                                if isDownloadingAllDependencies || hasDownloading {
                                    ProgressView().controlSize(.small)
                                } else {
                                    Text(
                                        "dependency.download_all_and_continue"
                                            .localized()
                                    )
                                }
                            }
                            .keyboardShortcut(.defaultAction)
                            .disabled(
                                isDownloadingAllDependencies || hasDownloading
                            )

                        case .failed:
                            Button {
                                actionViewModel.downloadAll(onDownloadAll: onDownloadAll)
                            } label: {
                                if isDownloadingAllDependencies || hasDownloading {
                                    ProgressView().controlSize(.small)
                                } else {
                                    Text("common.continue".localized())
                                }
                            }
                            .keyboardShortcut(.defaultAction)
                            .disabled(
                                isDownloadingAllDependencies || hasDownloading
                                    || !viewModel.allDependenciesDownloaded
                            )

                        case .retrying:
                            EmptyView()
                        }
                    }
                } else {
                    HStack {
                        Spacer()
                        Button("common.close".localized()) {
                            viewModel.showDependenciesSheet = false
                        }
                    }
                }
            }
        )
        .alert(
            "error.notification.download.title".localized(),
            isPresented: Binding(
                get: { actionViewModel.error != nil },
                set: { if !$0 { actionViewModel.error = nil } }
            )
        ) {
            Button("common.close".localized()) {
                actionViewModel.error = nil
            }
        } message: {
            if let error = actionViewModel.error {
                Text(error.chineseMessage)
            }
        }
    }
}
