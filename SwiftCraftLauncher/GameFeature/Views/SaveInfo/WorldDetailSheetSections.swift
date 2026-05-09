import AppKit
import SwiftUI

struct SeedCopyRow: View {
    let seed: Int64
    @State private var isCopied = false

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Text("saveinfo.world.detail.label.seed".localized() + ":")
                .font(.headline)
            Text(seed, format: .number.grouping(.never))
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString("\(seed)", forType: .string)
                isCopied = true
            } label: {
                Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 12))
                    .applyReplaceTransition()
            }
            .task(id: isCopied) {
                guard isCopied else { return }
                try? await Task.sleep(for: .seconds(1.5))
                isCopied = false
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct WorldDetailInfoSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
                .padding(.bottom, 10)
            content()
        }
    }
}

private struct WorldDetailInfoRow: View {
    let label: String
    let value: String
    var isMultiline: Bool = false

    var body: some View {
        HStack(alignment: isMultiline ? .top : .center, spacing: 12) {
            Text(label + ":")
                .font(.subheadline)
                .foregroundColor(.secondary)
            if isMultiline {
                Text(value)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text(value)
                    .font(.subheadline)
                    .foregroundColor(.primary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct WorldDetailBasicInfoSectionView: View {
    let metadata: WorldDetailMetadata

    var body: some View {
        WorldDetailInfoSection(title: "saveinfo.world.detail.section.basic".localized()) {
            WorldDetailInfoRow(label: "saveinfo.world.detail.label.level_name".localized(), value: metadata.levelName)
            WorldDetailInfoRow(label: "saveinfo.world.detail.label.folder_name".localized(), value: metadata.folderName)
            if let versionName = metadata.versionName {
                WorldDetailInfoRow(label: "saveinfo.world.detail.label.game_version".localized(), value: versionName)
            }
            if let versionId = metadata.versionId {
                WorldDetailInfoRow(label: "saveinfo.world.detail.label.version_id".localized(), value: "\(versionId)")
            }
            if let dataVersion = metadata.dataVersion {
                WorldDetailInfoRow(label: "saveinfo.world.detail.label.data_version".localized(), value: "\(dataVersion)")
            }
        }
    }
}

struct WorldDetailGameSettingsSectionView: View {
    let metadata: WorldDetailMetadata

    var body: some View {
        WorldDetailInfoSection(title: "saveinfo.world.detail.section.game_settings".localized()) {
            WorldDetailInfoRow(label: "saveinfo.world.detail.label.game_mode".localized(), value: metadata.gameMode)
            WorldDetailInfoRow(label: "saveinfo.world.detail.label.difficulty".localized(), value: metadata.difficulty)
            WorldDetailInfoRow(
                label: "saveinfo.world.detail.label.hardcore".localized(),
                value: metadata.hardcore ? "common.yes".localized() : "common.no".localized()
            )
            WorldDetailInfoRow(
                label: "saveinfo.world.detail.label.cheats".localized(),
                value: metadata.cheats ? "common.yes".localized() : "common.no".localized()
            )
        }
    }
}

struct WorldDetailOtherInfoSectionView: View {
    let metadata: WorldDetailMetadata

    var body: some View {
        WorldDetailInfoSection(title: "saveinfo.world.detail.section.other".localized()) {
            if let lastPlayed = metadata.lastPlayed {
                WorldDetailInfoRow(label: "saveinfo.world.detail.label.last_played".localized(), value: formatDate(lastPlayed))
            }
            if let spawn = metadata.spawn {
                WorldDetailInfoRow(label: "saveinfo.world.detail.label.spawn".localized(), value: spawn)
            }
            if let time = metadata.time {
                WorldDetailInfoRow(label: "saveinfo.world.detail.label.time".localized(), value: "\(time)")
            }
            if let dayTime = metadata.dayTime {
                WorldDetailInfoRow(label: "saveinfo.world.detail.label.day_time".localized(), value: "\(dayTime)")
            }
            if let weather = metadata.weather {
                WorldDetailInfoRow(label: "saveinfo.world.detail.label.weather".localized(), value: weather)
            }
            if let border = metadata.worldBorder {
                WorldDetailInfoRow(
                    label: "saveinfo.world.detail.label.world_border".localized(),
                    value: border,
                    isMultiline: true
                )
            }
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale.current
        return formatter.string(from: date)
    }
}

struct WorldDetailPathRowView: View {
    let worldPath: URL

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Text("saveinfo.world.detail.label.world_path".localized() + ":")
                .font(.headline)
            Button {
                NSWorkspace.shared.selectFile(worldPath.path, inFileViewerRootedAtPath: "")
            } label: {
                PathBreadcrumbView(path: worldPath.path)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .font(.caption)
                    .applyPointerHandIfAvailable()
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct WorldDetailRawDataToggleView: View {
    let filteredRawData: [String: Any]
    @Binding var showRawData: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation {
                    showRawData.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: showRawData ? "chevron.down" : "chevron.right")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("saveinfo.world.detail.toggle.detailed_info".localized())
                        .font(.headline)
                    Spacer()
                }
            }
            .buttonStyle(.plain)

            if showRawData {
                NBTStructureView(data: filteredRawData)
            }
        }
    }
}
