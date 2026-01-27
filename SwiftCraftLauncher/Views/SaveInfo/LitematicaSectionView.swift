import SwiftUI
import AppKit

// MARK: - Litematica 投影文件区域视图
struct LitematicaSectionView: View {
    // MARK: - Properties
    let litematicaFiles: [LitematicaInfo]
    let isLoading: Bool
    let gameName: String

    @State private var selectedFile: LitematicaInfo?

    // MARK: - Body
    var body: some View {
        GenericSectionView(
            title: "saveinfo.litematica",
            items: litematicaFiles,
            isLoading: isLoading,
            iconName: "square.stack.3d.up"
        ) { file in
            litematicaChip(for: file)
        }
        .sheet(item: $selectedFile) { file in
            LitematicaDetailSheetView(filePath: file.path, gameName: gameName)
        }
    }
    
    // MARK: - Chip Builder
    private func litematicaChip(for file: LitematicaInfo) -> some View {
        FilterChip(
            title: file.name,
            action: {
                selectedFile = file
            },
            iconName: "square.stack.3d.up",
            isLoading: false,
            verticalPadding: 6,
            maxTextWidth: 150
        )
    }
}

// MARK: - Litematica File Row
struct LitematicaFileRow: View {
    let file: LitematicaInfo

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(file.name)
                    .font(.headline)

                if let author = file.author {
                    Text(String(format: "saveinfo.litematica.author".localized(), author))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if let description = file.description, !description.isEmpty {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                HStack(spacing: 8) {
                    if let regionCount = file.regionCount {
                        Label(String(format: "saveinfo.litematica.region_count".localized(), regionCount), systemImage: "square.grid.2x2")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    if let totalBlocks = file.totalBlocks {
                        Label(String(format: "saveinfo.litematica.block_count".localized(), totalBlocks), systemImage: "cube")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()

            Button {
                NSWorkspace.shared.open(file.path.deletingLastPathComponent())
            } label: {
                Image(systemName: "folder.fill")
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }
}
