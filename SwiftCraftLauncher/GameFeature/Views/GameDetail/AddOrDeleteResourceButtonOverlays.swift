import SwiftUI

struct AddOrDeleteResourceButtonOverlays: ViewModifier {
    @ObservedObject var viewModel: AddOrDeleteResourceButtonViewModel

    let project: ModrinthProject
    let gameInfo: GameVersionInfo?
    let query: String

    let gameRepository: GameRepository

    func body(content: Content) -> some View {
        content
            .confirmationDialog(
                "common.delete".localized(),
                isPresented: $viewModel.showDeleteAlert,
                titleVisibility: .visible
            ) {
                Button("common.delete".localized(), role: .destructive) {
                    viewModel.confirmDelete()
                }
                .keyboardShortcut(.defaultAction)

                Button("common.cancel".localized(), role: .cancel) {}
            } message: {
                Text(
                    String(
                        format: "resource.delete.confirm".localized(),
                        project.title
                    )
                )
            }
            .sheet(
                isPresented: $viewModel.showGlobalResourceSheet,
                onDismiss: viewModel.onGlobalResourceSheetDismiss
            ) {
                GlobalResourceSheet(
                    project: project,
                    resourceType: query,
                    isPresented: $viewModel.showGlobalResourceSheet,
                    preloadedDetail: viewModel.preloadedDetail,
                    preloadedCompatibleGames: viewModel.preloadedCompatibleGames
                )
                .environmentObject(gameRepository)
                .onDisappear { viewModel.onGlobalResourceSheetDismiss() }
            }
            .sheet(
                isPresented: $viewModel.showModPackDownloadSheet,
                onDismiss: viewModel.onModPackDownloadSheetDismiss
            ) {
                ModPackDownloadSheet(
                    projectId: project.projectId,
                    gameInfo: gameInfo,
                    query: query,
                    preloadedDetail: viewModel.preloadedDetail
                )
                .environmentObject(gameRepository)
                .onDisappear { viewModel.onModPackDownloadSheetDismiss() }
            }
            .sheet(
                isPresented: $viewModel.showGameResourceInstallSheet,
                onDismiss: viewModel.onGameResourceInstallSheetDismiss
            ) {
                if let gameInfo = gameInfo {
                    GameResourceInstallSheet(
                        project: project,
                        resourceType: query,
                        gameInfo: gameInfo,
                        isPresented: $viewModel.showGameResourceInstallSheet,
                        preloadedDetail: viewModel.preloadedDetail,
                        isUpdateMode: viewModel.oldFileNameForUpdate != nil
                    ) { newFileName, newHash in
                        viewModel.handleInstallSuccess(newFileName: newFileName, newHash: newHash)
                    }
                    .environmentObject(gameRepository)
                }
            }
            .alert(item: $viewModel.activeAlert) { $0.alert }
    }
}
