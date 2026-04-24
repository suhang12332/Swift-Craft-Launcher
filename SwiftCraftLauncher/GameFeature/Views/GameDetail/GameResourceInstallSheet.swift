import SwiftUI

// MARK: - 游戏资源安装 Sheet（预置游戏信息，无需选择游戏）
struct GameResourceInstallSheet: View {
    let project: ModrinthProject
    let resourceType: String
    let gameInfo: GameVersionInfo  // 预置的游戏信息
    @Binding var isPresented: Bool
    let preloadedDetail: ModrinthProjectDetail?  // 预加载的项目详情
    var isUpdateMode: Bool = false  // 更新模式：footer 显示「下载」、不显示依赖
    @EnvironmentObject private var gameRepository: GameRepository
    /// 下载成功回调，参数为 (fileName, hash)，仅 downloadResource 路径会传值，downloadAllManual 传 (nil, nil)
    var onDownloadSuccess: ((String?, String?) -> Void)?

    @StateObject private var viewModel: GameResourceInstallSheetViewModel

    init(
        project: ModrinthProject,
        resourceType: String,
        gameInfo: GameVersionInfo,
        isPresented: Binding<Bool>,
        preloadedDetail: ModrinthProjectDetail?,
        isUpdateMode: Bool = false,
        onDownloadSuccess: ((String?, String?) -> Void)? = nil
    ) {
        self.project = project
        self.resourceType = resourceType
        self.gameInfo = gameInfo
        self._isPresented = isPresented
        self.preloadedDetail = preloadedDetail
        self.isUpdateMode = isUpdateMode
        self.onDownloadSuccess = onDownloadSuccess
        _viewModel = StateObject(
            wrappedValue: GameResourceInstallSheetViewModel(
                project: project,
                resourceType: resourceType,
                gameInfo: gameInfo,
                isUpdateMode: isUpdateMode
            )
        )
    }

    var body: some View {
        CommonSheetView(
            header: {
                Text(
                    String(
                        format: "global_resource.add_for_game".localized(),
                        gameInfo.gameName
                    )
                )
                .font(.headline)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
            },
            body: {
                if let detail = preloadedDetail {
                    VStack {
                        ModrinthProjectTitleView(
                            projectDetail: detail
                        ).padding(.bottom, 18)
                        VersionPickerForSheet(
                            project: project,
                            resourceType: resourceType,
                            selectedGame: .constant(gameInfo),  // 预置游戏信息
                            selectedVersion: $viewModel.selectedVersion,
                            availableVersions: $viewModel.availableVersions,
                            mainVersionId: $viewModel.mainVersionId
                        ) { version in
                            viewModel.onVersionChanged(version)
                        }
                        if resourceType == ResourceType.mod.rawValue, !isUpdateMode {
                            if viewModel.dependencyState.isLoading
                                || !viewModel.dependencyState.dependencies.isEmpty {
                                DependencySectionView(state: $viewModel.dependencyState)
                            }
                        }
                    }
                }
            },
            footer: {
                GameResourceInstallFooter(
                    isPresented: $isPresented,
                    projectDetail: preloadedDetail,
                    viewModel: viewModel,
                    onDownloadSuccess: onDownloadSuccess
                )
            }
        )
        .onAppear { viewModel.setDependencies(gameRepository: gameRepository) }
        .onDisappear { viewModel.cleanup() }
    }
}

// MARK: - Footer 按钮区块
struct GameResourceInstallFooter: View {
    @Binding var isPresented: Bool
    let projectDetail: ModrinthProjectDetail?
    @ObservedObject var viewModel: GameResourceInstallSheetViewModel
    /// 下载成功回调，参数为 (fileName, hash)，仅 downloadResource 路径会传值，downloadAllManual 传 (nil, nil)
    var onDownloadSuccess: ((String?, String?) -> Void)?

    var body: some View {
        Group {
            if projectDetail != nil {
                HStack {
                    Button("common.close".localized()) { isPresented = false }
                    Spacer()
                    if viewModel.resourceType == ResourceType.mod.rawValue,
                        !viewModel.isUpdateMode {
                        // 安装模式下的 mod：显示「下载全部」（含依赖）
                        if !viewModel.dependencyState.isLoading {
                            if viewModel.selectedVersion != nil {
                                Button {
                                    viewModel.downloadAllManual(
                                        onSuccess: { fileName, hash in
                                            onDownloadSuccess?(fileName, hash)
                                        },
                                        dismiss: { isPresented = false }
                                    )
                                } label: {
                                    if viewModel.isDownloadingAll {
                                        ProgressView().controlSize(.small)
                                    } else {
                                        Text(
                                            "global_resource.download_all"
                                                .localized()
                                        )
                                    }
                                }
                                .disabled(viewModel.isDownloadingAll)
                                .keyboardShortcut(.defaultAction)
                            }
                        }
                    } else {
                        // 非 mod，或更新模式：显示「下载」（仅主资源）
                        if viewModel.selectedVersion != nil {
                            Button {
                                viewModel.downloadResource(
                                    onSuccess: { fileName, hash in
                                        onDownloadSuccess?(fileName, hash)
                                    },
                                    dismiss: { isPresented = false }
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
            } else {
                HStack {
                    Spacer()
                    Button("common.close".localized()) { isPresented = false }
                }
            }
        }
    }
}
