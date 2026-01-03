//
//  MainModVersionSheetView.swift
//  SwiftCraftLauncher
//
//  Created by su on 2025/1/1.
//

import SwiftUI

struct MainModVersionSheetView: View {
    @ObservedObject var viewModel: MainModVersionSheetViewModel
    let projectDetail: ModrinthProjectDetail
    @Binding var isDownloading: Bool
    @State private var error: GlobalError?

    // 新增：用于加载依赖和下载
    let project: ModrinthProject
    let resourceType: String
    let gameInfo: GameVersionInfo?
    let gameRepository: GameRepository
    let onDownload: () async -> Void
    let onDownloadAll: (() async -> Void)?  // 下载所有依赖和主资源
    let onDownloadMainOnly: (() async -> Void)?  // 仅下载主资源

    var body: some View {
        CommonSheetView(
            header: {
                Text("main_mod.version.title".localized())
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
            },
            body: {
                if viewModel.isLoadingVersions {
                    ProgressView().frame(height: 100).controlSize(.small)
                } else {
                    ModrinthProjectTitleView(projectDetail: projectDetail)
                    VStack(alignment: .leading, spacing: 12) {
                        if !viewModel.availableVersions.isEmpty {
                            Text(projectDetail.title)
                                .font(.headline)
                                .foregroundColor(.primary)
                            Picker(
                                "main_mod.version.picker".localized(),
                                selection: Binding(
                                    get: {
                                        viewModel.selectedVersionId
                                            ?? viewModel.availableVersions.first?.id ?? ""
                                    },
                                    set: { newValue in
                                        viewModel.selectedVersionId = newValue
                                        // 版本改变时，如果是 mod 类型，加载依赖
                                        if resourceType == "mod",
                                           let gameInfo = gameInfo,
                                           let selectedVersion = viewModel.availableVersions.first(where: { $0.id == newValue }) {
                                            loadDependencies(for: selectedVersion, game: gameInfo)
                                        } else {
                                            viewModel.dependencyState = DependencyState()
                                        }
                                    }
                                )
                            ) {
                                ForEach(viewModel.availableVersions, id: \.id) { version in
                                    Text(version.name).tag(version.id)
                                }
                            }
                            .pickerStyle(.menu)
                            .font(.subheadline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .onChange(of: viewModel.availableVersions) { _, _ in
                                // 版本列表加载完成后，如果有选中的版本且是 mod 类型，自动加载依赖
                                if resourceType == "mod",
                                   let gameInfo = gameInfo,
                                   let selectedVersionId = viewModel.selectedVersionId,
                                   let selectedVersion = viewModel.availableVersions.first(where: { $0.id == selectedVersionId }) {
                                    loadDependencies(for: selectedVersion, game: gameInfo)
                                }
                            }

                            // 依赖展示区域（仅 mod 类型显示）
                            if resourceType == "mod" {
                                if viewModel.dependencyState.isLoading || !viewModel.dependencyState.dependencies.isEmpty {
                                    spacerView()
                                    DependencySectionView(state: $viewModel.dependencyState)
                                }
                            }
                        } else {
                            Text("main_mod.version.no_versions".localized())
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            },
            footer: {
                HStack {
                    Button("common.close".localized()) {
                        viewModel.showMainModVersionSheet = false
                    }
                    Spacer()

                    if !viewModel.availableVersions.isEmpty {
                        // 如果是 mod 类型且有依赖，显示下载所有按钮
                        if resourceType == "mod" && !viewModel.dependencyState.dependencies.isEmpty && !viewModel.dependencyState.isLoading {
                            if let onDownloadAll = onDownloadAll {
                                Button {
                                    Task {
                                        await onDownloadAll()
                                    }
                                } label: {
                                    if isDownloading {
                                        ProgressView().controlSize(.small)
                                    } else {
                                        Text("global_resource.download_all".localized())
                                    }
                                }
                                .keyboardShortcut(.defaultAction)
                                .disabled(isDownloading)
                            }
                        } else {
                            // 其他情况，显示普通下载按钮
                            Button {
                                Task {
                                    await onDownload()
                                }
                            } label: {
                                if isDownloading {
                                    ProgressView().controlSize(.small)
                                } else {
                                    Text("main_mod.version.download".localized())
                                }
                            }
                            .keyboardShortcut(.defaultAction)
                            .disabled(isDownloading)
                        }
                    }
                }
            }
        )
        .alert(
            "error.notification.download.title".localized(),
            isPresented: .constant(error != nil)
        ) {
            Button("common.close".localized()) {
                error = nil
            }
        } message: {
            if let error = error {
                Text(error.chineseMessage)
            }
        }
    }

    // 加载依赖（和全局资源安装逻辑一致）
    private func loadDependencies(
        for version: ModrinthProjectDetailVersion,
        game: GameVersionInfo
    ) {
        viewModel.dependencyState.isLoading = true
        Task {
            do {
                try await loadDependenciesThrowing(for: version, game: game)
            } catch {
                let globalError = GlobalError.from(error)
                Logger.shared.error("加载依赖项失败: \(globalError.chineseMessage)")
                GlobalErrorHandler.shared.handle(globalError)
                _ = await MainActor.run {
                    viewModel.dependencyState = DependencyState()
                }
            }
        }
    }

    private func loadDependenciesThrowing(
        for version: ModrinthProjectDetailVersion,
        game: GameVersionInfo
    ) async throws {
        guard !project.projectId.isEmpty else {
            throw GlobalError.validation(
                chineseMessage: "项目ID不能为空",
                i18nKey: "error.validation.project_id_empty",
                level: .notification
            )
        }

        // 获取缺失的依赖项（包含版本信息）
        let missingWithVersions =
            await ModrinthDependencyDownloader
            .getMissingDependenciesWithVersions(
                for: project.projectId,
                gameInfo: game
            )

        var depVersions: [String: [ModrinthProjectDetailVersion]] = [:]
        var depSelected: [String: ModrinthProjectDetailVersion?] = [:]
        var dependencies: [ModrinthProjectDetail] = []

        for (detail, versions) in missingWithVersions {
            dependencies.append(detail)
            depVersions[detail.id] = versions
            depSelected[detail.id] = versions.first
        }

        _ = await MainActor.run {
            viewModel.dependencyState = DependencyState(
                dependencies: dependencies,
                versions: depVersions,
                selected: depSelected,
                isLoading: false
            )
        }
    }
}
