//
//  VersionSelectionView.swift
//  ModPackFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import SwiftUI

/// Allows the user to pick a game version and a modpack version for download.
struct VersionSelectionView: View {
    @Binding var selectedGameVersion: String
    @Binding var selectedModPackVersion: ModrinthProjectDetailVersion?

    let availableGameVersions: [String]
    let filteredModPackVersions: [ModrinthProjectDetailVersion]
    let isLoadingModPackVersions: Bool
    let isProcessing: Bool

    let onGameVersionChange: (String) -> Void
    let onModPackVersionAppear: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            gameVersionPicker
            if !selectedGameVersion.isEmpty {
                modPackVersionPicker
            }
        }
    }

    private var gameVersionPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("game.version".localized())
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            CommonMenuPicker(
                selection: $selectedGameVersion,
            ) {
                Text("global_resource.select_game".localized())
            } content: {
                if availableGameVersions.isEmpty {
                    Text(String(format: "error.resource.modpack_game_version_unsupported".localized(), AppConstants.MinecraftVersions.featureBaseline))
                        .tag("")
                } else {
                    Text("global_resource.please_select_game".localized())
                        .tag("")
                    ForEach(availableGameVersions, id: \.self) { version in
                        Text(version).tag(version)
                    }
                }
            }
            .disabled(availableGameVersions.isEmpty)
            .onChange(of: selectedGameVersion) { _, newValue in
                onGameVersionChange(newValue)
            }
        }
    }

    private var modPackVersionPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            if isLoadingModPackVersions {
                Text("modpack.version".localized())
                    .font(.headline)
                HStack {
                    ProgressView()
                        .controlSize(.small)
                        .frame(maxWidth: .infinity)
                }
            } else if !selectedGameVersion.isEmpty {
                Text("modpack.version".localized())
                    .font(.headline)
                CommonMenuPicker(
                    selection: $selectedModPackVersion,
                ) {
                    Text("global_resource.select_version".localized())
                } content: {
                    ForEach(filteredModPackVersions, id: \.id) { version in
                        Text(version.name).tag(
                            version as ModrinthProjectDetailVersion?,
                        )
                    }
                }
                .onAppear {
                    onModPackVersionAppear()
                }
            }
        }
        .onChange(of: selectedGameVersion) { _, _ in
            selectedModPackVersion = nil
        }
    }
}
