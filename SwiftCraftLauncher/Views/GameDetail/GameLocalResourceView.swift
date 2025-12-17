import SwiftUI

struct GameLocalResourceView: View {
    let game: GameVersionInfo
    let query: String
    @Binding var selectedItem: SidebarItem
    @Binding var selectedProjectId: String?
    let refreshToken: UUID

    @State private var searchTextForResource = ""
    @State private var scannedResources: [ModrinthProjectDetail] = []
    @State private var isLoadingResources = false
    @State private var error: GlobalError?

    var body: some View {
        VStack {
            if isLoadingResources {
                ProgressView()
                    .padding()
            } else {
                let filteredResources = scannedResources.filter { res in
                    searchTextForResource.isEmpty
                        || res.title.localizedCaseInsensitiveContains(
                            searchTextForResource
                        )
                }
                .map { ModrinthProject.from(detail: $0) }

                ForEach(filteredResources, id: \.projectId) { mod in
                    ModrinthDetailCardView(
                        project: mod,
                        selectedVersions: [game.gameVersion],
                        selectedLoaders: [game.modLoader],
                        gameInfo: game,
                        query: query,
                        type: false,
                        selectedItem: $selectedItem
                    ) {
                        scanResources()
                    }
                    .padding(.vertical, ModrinthConstants.UIConstants.verticalPadding)
                    .listRowInsets(
                        EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8)
                    )
                    .onTapGesture {
                        // 本地资源不跳转详情页面
                        if mod.author != "local" {
                            selectedProjectId = mod.projectId
                            if let type = ResourceType(rawValue: query) {
                                selectedItem = .resource(type)
                            }
                        }
                    }
                }
            }
        }
        .searchable(
            text: $searchTextForResource,
            placement: .toolbar,
            prompt: "search.resources".localized()
        )
        .help("search.resources".localized())
        .onAppear {
            scanResources()
        }
        .onChange(of: refreshToken) { _, _ in
            scanResources()
        }
        .alert(
            "error.notification.validation.title".localized(),
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

    private func scanResources() {
        guard !isLoadingResources else { return }

        // Modpacks don't have a local directory to scan, skip scanning
        if query.lowercased() == "modpack" {
            scannedResources = []
            isLoadingResources = false
            return
        }

        guard
            let resourceDir = AppPaths.resourceDirectory(
                for: query,
                gameName: game.gameName
            )
        else {
            let globalError = GlobalError.configuration(
                chineseMessage: "无法获取资源目录路径",
                i18nKey: "error.configuration.resource_directory_not_found",
                level: .notification
            )
            Logger.shared.error("扫描资源失败: \(globalError.chineseMessage)")
            GlobalErrorHandler.shared.handle(globalError)
            error = globalError
            scannedResources = []
            isLoadingResources = false
            return
        }

        isLoadingResources = true
        error = nil
        ModScanner.shared.scanResourceDirectory(resourceDir) { details in
            DispatchQueue.main.async {
                scannedResources = details
                isLoadingResources = false
            }
        }
    }
}
