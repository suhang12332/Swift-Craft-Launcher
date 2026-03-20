import SwiftUI

struct GameLocalResourceListContent: View {
    let game: GameVersionInfo
    let query: String
    @ObservedObject var viewModel: GameLocalResourceViewModel

    @Binding var selectedItem: SidebarItem
    @Binding var selectedProjectId: String?
    let onResourceChanged: () -> Void

    var body: some View {
        Group {
            if let error = viewModel.error {
                VStack { Text(error.chineseMessage) }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .listRowSeparator(.hidden)
            } else if viewModel.isLoadingResources && viewModel.displayedResources.isEmpty {
                HStack { ProgressView().controlSize(.small) }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .listRowSeparator(.hidden)
            } else if viewModel.hasLoaded && viewModel.displayedResources.isEmpty {
                EmptyView()
            } else {
                ForEach(
                    viewModel.displayedResources.map { ModrinthProject.from(detail: $0) },
                    id: \.projectId
                ) { mod in
                    ModrinthDetailCardView(
                        project: mod,
                        selectedVersions: [game.gameVersion],
                        selectedLoaders: [game.modLoader],
                        gameInfo: game,
                        query: query,
                        type: false,
                        selectedItem: $selectedItem,
                        onResourceChanged: onResourceChanged,
                        onLocalDisableStateChanged: { project, isDisabled in
                            guard let oldFileName = project.fileName else { return }
                            viewModel.handleLocalDisableStateChanged(
                                projectId: project.projectId,
                                oldFileName: oldFileName,
                                isDisabled: isDisabled
                            )
                        },
                        onResourceUpdated: { projectId, oldFileName, newFileName, newHash in
                            viewModel.handleResourceUpdated(
                                projectId: projectId,
                                oldFileName: oldFileName,
                                newFileName: newFileName,
                                newHash: newHash
                            )
                        },
                        scannedDetailIds: .constant([])
                    )
                    .padding(.vertical, ModrinthConstants.UIConstants.verticalPadding)
                    .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
                    .listRowSeparator(.hidden)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if !mod.projectId.hasPrefix("local_") && !mod.projectId.hasPrefix("file_") {
                            selectedProjectId = mod.projectId
                            if let type = ResourceType(rawValue: query) {
                                selectedItem = .resource(type)
                            }
                        }
                    }
                    .onAppear {
                        viewModel.loadNextPageIfNeeded(currentProjectId: mod.projectId)
                    }
                }
            }
        }
    }
}
