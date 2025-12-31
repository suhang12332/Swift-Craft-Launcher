import SwiftUI

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
            Text("modpack.game.version".localized())
                .foregroundColor(.primary)
            Picker(
                "",
                selection: $selectedGameVersion
            ) {
                Text("modpack.game.version.placeholder".localized()).tag("")
                ForEach(availableGameVersions, id: \.self) { version in
                    Text(version).tag(version)
                }
            }
            .pickerStyle(MenuPickerStyle())
            .font(.subheadline)
            .labelsHidden()
            .onChange(of: selectedGameVersion) { _, newValue in
                onGameVersionChange(newValue)
            }
        }
    }

    private var modPackVersionPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            if isLoadingModPackVersions {
                Text("modpack.version".localized())
                    .foregroundColor(.primary)
                HStack {
                    ProgressView()
                        .controlSize(.small).frame(maxWidth: .infinity)
                }
            } else if !selectedGameVersion.isEmpty {
                Text("modpack.version".localized())
                    .foregroundColor(.primary)
                Picker(
                    "",
                    selection: $selectedModPackVersion
                ) {
                    ForEach(filteredModPackVersions, id: \.id) { version in
                        Text(version.name).tag(
                            version as ModrinthProjectDetailVersion?
                        )
                    }
                }
                .labelsHidden()
                .font(.subheadline)
                .pickerStyle(MenuPickerStyle())
                .onAppear {
                    onModPackVersionAppear()
                }
            }
        }
    }
}
