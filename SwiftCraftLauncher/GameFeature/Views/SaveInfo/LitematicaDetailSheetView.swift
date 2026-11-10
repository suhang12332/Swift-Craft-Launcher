//
//  LitematicaDetailSheetView.swift
//  GameFeature
//
//  © 2025 Swift Craft Launcher Team. All rights reserved.
//

// Displays detailed metadata for a Litematica schematic file.
import SwiftUI

struct LitematicaDetailSheetView: View {
    @Environment(DIContainer.self)
    private var container
    let filePath: URL
    @Environment(\.dismiss)
    private var dismiss

    @State private var metadata: LitematicMetadata?
    @State private var isLoading = true

    init(filePath: URL) {
        self.filePath = filePath
    }

    var body: some View {
        CommonSheetView(
            header: { headerView },
            body: { bodyView },
            footer: { footerView },
        )
        .frame(minWidth: 500)
        .task {
            await loadMetadata()
        }
    }

    private var headerView: some View {
        HStack {
            Text("litematica.detail.title".localized())
                .font(.headline)
            Spacer()
            ShareLink(item: filePath) {
                Image(systemName: "square.and.arrow.up")
                    .font(.title3)
            }
            .buttonStyle(.borderless)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder private var bodyView: some View {
        if isLoading {
            loadingView
        } else if let metadata {
            metadataContentView(metadata: metadata)
        } else {
            errorView
        }
    }

    private var loadingView: some View {
        ProgressView()
            .controlSize(.small)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
    }

    private var errorView: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(.orange)
            Text("litematica.detail.load_failed".localized())
                .font(.headline)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    func metadataContentView(metadata: LitematicMetadata) -> some View {
        let hasSize = metadata.enclosingSize.x > 0 || metadata.enclosingSize.y > 0 || metadata.enclosingSize.z > 0
        let airBlocks = max(0, Int(metadata.totalVolume) - Int(metadata.totalBlocks))
        let fillRatio = metadata.totalVolume > 0
            ? min(max(Double(metadata.totalBlocks) / Double(metadata.totalVolume), 0), 1)
            : 0

        return VStack(alignment: .leading, spacing: 16) {
            LazyVGrid(columns: fieldColumns, alignment: .leading, spacing: 16) {
                infoRow(label: "litematica.detail.field.name".localized(), value: metadata.name)
                infoRow(label: "litematica.detail.field.author".localized(), value: metadata.author.isEmpty ? "common.unknown".localized() : metadata.author)
                infoRow(label: "litematica.detail.field.created".localized(), value: formatTimestamp(metadata.timeCreated))
                infoRow(label: "litematica.detail.field.modified".localized(), value: formatTimestamp(metadata.timeModified))

                if hasSize {
                    infoRow(
                        label: "litematica.detail.field.enclosing_size".localized(),
                        value: "\(metadata.enclosingSize.x) × \(metadata.enclosingSize.y) × \(metadata.enclosingSize.z)",
                    )
                } else {
                    infoRow(label: "litematica.detail.field.enclosing_size".localized(), value: "common.unknown".localized())
                }

                if metadata.totalVolume > 0 {
                    infoRow(label: "litematica.detail.field.total_volume".localized(), value: formatNumber(Int(metadata.totalVolume)))
                } else {
                    infoRow(label: "litematica.detail.field.total_volume".localized(), value: "common.unknown".localized())
                }

                if metadata.totalBlocks > 0 {
                    infoRow(label: "litematica.detail.field.total_blocks".localized(), value: formatNumber(Int(metadata.totalBlocks)))
                } else {
                    infoRow(label: "litematica.detail.field.total_blocks".localized(), value: "common.unknown".localized())
                }

                infoRow(label: "litematica.detail.field.region_count".localized(), value: "\(metadata.regionCount)")

                if metadata.totalVolume > 0 {
                    infoRow(label: "litematica.detail.field.air_blocks".localized(), value: formatNumber(airBlocks))
                    infoRow(label: "litematica.detail.field.fill_ratio".localized(), value: formatPercent(fillRatio))
                } else {
                    infoRow(label: "litematica.detail.field.air_blocks".localized(), value: "common.unknown".localized())
                    infoRow(label: "litematica.detail.field.fill_ratio".localized(), value: "common.unknown".localized())
                }
            }

            if !metadata.description.isEmpty {
                infoRow(label: "litematica.detail.field.description".localized(), value: metadata.description)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
    }

    private var fieldColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 200), spacing: 24, alignment: .leading)]
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(label + ":")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(1)
            Text(value)
                .font(.subheadline)
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var footerView: some View {
        HStack {
            Label {
                Text(filePath.lastPathComponent)
                    .lineLimit(1)
                    .truncationMode(.middle)
            } icon: {
                Image(systemName: "square.stack.3d.up")
            }
            .font(.caption)
            .foregroundColor(.secondary)
            .frame(maxWidth: 300, alignment: .leading)

            Spacer()

            Button("common.close".localized()) {
                dismiss()
            }
            .keyboardShortcut(.defaultAction)
        }
    }

    private func loadMetadata() async {
        isLoading = true

        do {
            AppLog.game.debug("Starting to load litematica details: \(filePath.lastPathComponent)")
            let loadedMetadata = try await container.system.litematicaService.loadFullMetadata(filePath: filePath)
            await MainActor.run {
                if let metadata = loadedMetadata {
                    AppLog.game.debug("Successfully loaded litematica metadata: \(metadata.name)")
                    self.metadata = metadata
                } else {
                    AppLog.game.error("Litematica metadata is nil: \(filePath.lastPathComponent)")
                    container.core.errorHandler.handle(GlobalError.fileSystem(
                        i18nKey: "litematica.detail.error.parse_failed",
                        level: .notification,
                    ))
                }
                isLoading = false
            }
        } catch {
            AppLog.game.error("Failed to load litematica details: \(error.localizedDescription)")
            await MainActor.run {
                isLoading = false
                container.core.errorHandler.handle(GlobalError.from(error))
            }
        }
    }

    private var appLocale: Locale {
        Locale(identifier: container.ui.languageManager.selectedLanguage)
    }

    private func formatNumber(_ number: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = appLocale
        return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
    }

    private func formatPercent(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.maximumFractionDigits = 1
        formatter.minimumFractionDigits = 0
        formatter.locale = appLocale
        return formatter.string(from: NSNumber(value: value)) ?? "\(value * 100)%"
    }

    private func formatTimestamp(_ timestamp: Int64) -> String {
        guard timestamp > 0 else {
            return "common.unknown".localized()
        }

        let date = Date(timeIntervalSince1970: TimeInterval(timestamp) / 1000.0)
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = appLocale
        return formatter.string(from: date)
    }
}
