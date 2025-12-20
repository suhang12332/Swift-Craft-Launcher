import SwiftUI

// MARK: - 版本选择区块
struct VersionPickerForSheet: View {
    let project: ModrinthProject
    let resourceType: String
    @Binding var selectedGame: GameVersionInfo?
    @Binding var selectedVersion: ModrinthProjectDetailVersion?
    @Binding var availableVersions: [ModrinthProjectDetailVersion]
    @Binding var mainVersionId: String
    var onVersionChange: ((ModrinthProjectDetailVersion?) -> Void)?
    @State private var isLoading = false
    @State private var error: GlobalError?

    var body: some View {
        VStack(alignment: .leading) {
            if isLoading {
                ProgressView().controlSize(.small)
            } else if !availableVersions.isEmpty {
                Text(project.title).font(.headline).bold().frame(
                    maxWidth: .infinity,
                    alignment: .leading
                )
                Picker(
                    "global_resource.select_version".localized(),
                    selection: $selectedVersion
                ) {
                    ForEach(availableVersions, id: \.id) { version in
                        if resourceType == "shader" {
                            let loaders = version.loaders.joined(
                                separator: ", "
                            )
                            Text("\(version.name) (\(loaders))").tag(
                                Optional(version)
                            )
                        } else {
                            Text(version.name).tag(Optional(version))
                        }
                    }
                }
                .pickerStyle(.menu)
            } else {
                Text("global_resource.no_version_available".localized())
                    .foregroundColor(.secondary)
            }
        }
        .onAppear(perform: loadVersions)
        .onChange(of: selectedGame) { loadVersions() }
        .onChange(of: selectedVersion) { _, newValue in
            // 更新主版本ID
            if let newValue = newValue {
                mainVersionId = newValue.id
            } else {
                mainVersionId = ""
            }
            onVersionChange?(newValue)
        }
    }

    private func loadVersions() {
        isLoading = true
        error = nil
        Task {
            do {
                try await loadVersionsThrowing()
            } catch {
                let globalError = GlobalError.from(error)
                _ = await MainActor.run {
                    self.error = globalError
                    self.isLoading = false
                }
            }
        }
    }

    private func loadVersionsThrowing() async throws {
        guard !project.projectId.isEmpty else {
            throw GlobalError.validation(
                chineseMessage: "项目ID不能为空",
                i18nKey: "error.validation.project_id_empty",
                level: .notification
            )
        }

        guard let game = selectedGame else {
            _ = await MainActor.run {
                availableVersions = []
                selectedVersion = nil
                mainVersionId = ""
                isLoading = false
            }
            return
        }

        // 使用服务端的过滤方法，减少客户端过滤
        let filtered = try await ModrinthService.fetchProjectVersionsFilter(
            id: project.projectId,
            selectedVersions: [game.gameVersion],
            selectedLoaders: [game.modLoader],
            type: resourceType
        )

        _ = await MainActor.run {
            availableVersions = filtered
            selectedVersion = filtered.first
            // 更新主版本ID
            if let firstVersion = filtered.first {
                mainVersionId = firstVersion.id
            } else {
                mainVersionId = ""
            }
            isLoading = false
        }
    }
}
