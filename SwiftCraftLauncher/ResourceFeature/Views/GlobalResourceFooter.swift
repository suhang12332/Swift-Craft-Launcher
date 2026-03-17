import SwiftUI

// MARK: - Footer 按钮区块
struct GlobalResourceFooter: View {
    let project: ModrinthProject
    let resourceType: String
    @Binding var isPresented: Bool
    let projectDetail: ModrinthProjectDetail?
    let selectedGame: GameVersionInfo?
    let selectedVersion: ModrinthProjectDetailVersion?
    let dependencyState: DependencyState
    @Binding var isDownloadingAll: Bool
    @Binding var isDownloadingMainOnly: Bool
    let gameRepository: GameRepository
    let loadDependencies:
        (ModrinthProjectDetailVersion, GameVersionInfo) -> Void
    @Binding var mainVersionId: String
    let compatibleGames: [GameVersionInfo]

    @StateObject private var viewModel: GlobalResourceFooterViewModel

    init(
        project: ModrinthProject,
        resourceType: String,
        isPresented: Binding<Bool>,
        projectDetail: ModrinthProjectDetail?,
        selectedGame: GameVersionInfo?,
        selectedVersion: ModrinthProjectDetailVersion?,
        dependencyState: DependencyState,
        isDownloadingAll: Binding<Bool>,
        isDownloadingMainOnly: Binding<Bool>,
        gameRepository: GameRepository,
        loadDependencies: @escaping (ModrinthProjectDetailVersion, GameVersionInfo) -> Void,
        mainVersionId: Binding<String>,
        compatibleGames: [GameVersionInfo]
    ) {
        self.project = project
        self.resourceType = resourceType
        self._isPresented = isPresented
        self.projectDetail = projectDetail
        self.selectedGame = selectedGame
        self.selectedVersion = selectedVersion
        self.dependencyState = dependencyState
        self._isDownloadingAll = isDownloadingAll
        self._isDownloadingMainOnly = isDownloadingMainOnly
        self.gameRepository = gameRepository
        self.loadDependencies = loadDependencies
        self._mainVersionId = mainVersionId
        self.compatibleGames = compatibleGames

        self._viewModel = StateObject(
            wrappedValue: GlobalResourceFooterViewModel(
                project: project,
                resourceType: resourceType,
                isPresented: isPresented,
                isDownloadingAll: isDownloadingAll,
                isDownloadingMainOnly: isDownloadingMainOnly,
                gameRepository: gameRepository
            )
        )
    }

    var body: some View {
        Group {
            if projectDetail != nil {
                if compatibleGames.isEmpty {
                    HStack {
                        Spacer()
                        Button("common.close".localized()) { isPresented = false }
                    }
                } else {
                    HStack {
                        Button("common.close".localized()) { isPresented = false }
                        Spacer()
                        if resourceType == ResourceType.mod.rawValue {
                            if !dependencyState.isLoading {
                                if selectedVersion != nil {
                                    Button(action: {
                                        viewModel.downloadAllManual(
                                            selectedGame: selectedGame,
                                            dependencyState: dependencyState,
                                            mainVersionId: mainVersionId
                                        )
                                    }, label: {
                                        if isDownloadingAll {
                                            ProgressView().controlSize(.small)
                                        } else {
                                            Text(
                                                "global_resource.download_all"
                                                    .localized()
                                            )
                                        }
                                    })
                                    .disabled(isDownloadingAll)
                                    .keyboardShortcut(.defaultAction)
                                }
                            }
                        } else if resourceType == ResourceType.minecraftJavaServer.rawValue {
                            if selectedGame != nil {
                                Button(action: {
                                    viewModel.addServerResource(
                                        selectedGame: selectedGame,
                                        projectDetail: projectDetail
                                    )
                                }, label: {
                                    if isDownloadingAll {
                                        ProgressView().controlSize(.small)
                                    } else {
                                        Text("saveinfo.server.add".localized())
                                    }
                                })
                                .disabled(isDownloadingAll)
                                .keyboardShortcut(.defaultAction)
                            }
                        } else {
                            if selectedVersion != nil {
                                Button(action: {
                                    viewModel.downloadResource(selectedGame: selectedGame)
                                }, label: {
                                    if isDownloadingAll {
                                        ProgressView().controlSize(.small)
                                    } else {
                                        Text("global_resource.download".localized())
                                    }
                                })
                                .disabled(isDownloadingAll)
                                .keyboardShortcut(.defaultAction)
                            }
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
