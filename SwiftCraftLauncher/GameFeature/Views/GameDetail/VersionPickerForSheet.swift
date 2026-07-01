//
//  VersionPickerForSheet.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

// A version picker for selecting resource versions within a sheet.
import SwiftUI

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
        VStack {
            if isLoading {
                ProgressView().controlSize(.small)
            } else if !availableVersions.isEmpty {
                Text(project.title).font(.headline).bold().frame(
                    maxWidth: .infinity,
                    alignment: .leading,
                )
                CommonMenuPicker(
                    selection: $selectedVersion,
                ) {
                    Text("global_resource.select_version".localized())
                } content: {
                    ForEach(availableVersions, id: \.id) { version in
                        if resourceType == ResourceType.shader.rawValue {
                            let loaders = version.loaders.joined(
                                separator: ", ",
                            )
                            Text(version.name + loaders).tag(
                                Optional(version),
                            )
                        } else {
                            Text(version.name).tag(Optional(version))
                        }
                    }
                }
            } else {
                Text("global_resource.no_version_available".localized())
                    .foregroundColor(.secondary)
            }
        }
        .onAppear(perform: loadVersions)
        .onChange(of: selectedGame) { loadVersions() }
        .onChange(of: selectedVersion) { _, newValue in
            if let newValue {
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
                    isLoading = false
                }
            }
        }
    }

    private func loadVersionsThrowing() async throws {
        guard !project.projectId.isEmpty else {
            throw GlobalError.validation(
                i18nKey: "error.validation.project_id_empty",
                message: "project.projectId is empty when loading versions for project=\(project.title)",
                level: .notification,
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

        let filtered = try await ModrinthService.fetchProjectVersionsFilter(
            id: project.projectId,
            selectedVersions: [game.gameVersion],
            selectedLoaders: [game.modLoader],
            type: resourceType,
        )

        _ = await MainActor.run {
            availableVersions = filtered
            selectedVersion = filtered.first
            if let firstVersion = filtered.first {
                mainVersionId = firstVersion.id
            } else {
                mainVersionId = ""
            }
            isLoading = false
        }
    }
}
