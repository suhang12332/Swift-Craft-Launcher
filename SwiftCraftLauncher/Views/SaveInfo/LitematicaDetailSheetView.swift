//
//  LitematicaDetailSheetView.swift
//  SwiftCraftLauncher
//
//  Created by su on 2025/1/20.
//

import SwiftUI

/// Litematica 投影详细信息视图
struct LitematicaDetailSheetView: View {
    // MARK: - Properties
    let filePath: URL
    let gameName: String
    @Environment(\.dismiss)
    private var dismiss

    @State private var metadata: LitematicMetadata?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showError = false

    // MARK: - Body
    var body: some View {
        CommonSheetView(
            header: { headerView },
            body: { bodyView },
            footer: { footerView }
        )
        .frame(minWidth: 500, minHeight: 400)
        .task {
            await loadMetadata()
        }
        .alert("common.error".localized(), isPresented: $showError) {
            Button("common.ok".localized(), role: .cancel) { }
        } message: {
            if let errorMessage = errorMessage {
                Text(errorMessage)
            }
        }
    }

    // MARK: - Header View
    private var headerView: some View {
        HStack {
            Text("litematica.detail.title".localized())
                .font(.headline)
            Spacer()
            HStack(spacing: 8) {
                ShareLink(item: filePath) {
                    Image(systemName: "square.and.arrow.up")
                }
                .buttonStyle(.plain)
                .help("saveinfo.share".localized())

                Button {
                    dismiss()  // 关闭当前视图
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Body View
    private var bodyView: some View {
        Group {
            if isLoading {
                loadingView
            } else if let metadata = metadata {
                metadataContentView(metadata: metadata)
            } else {
                errorView
            }
        }
    }

    private var loadingView: some View {
        VStack {
            ProgressView().controlSize(.small)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var errorView: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(.orange)
            Text("litematica.detail.load_failed".localized())
                .font(.headline)
            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    func metadataContentView(metadata: LitematicMetadata) -> some View {
        ScrollView {
            VStack {
                HStack {
                    // 基本信息
                    infoSection(title: "litematica.detail.section.basic".localized()) {
                        infoRow(label: "litematica.detail.field.name".localized(), value: metadata.name)
                        infoRow(label: "litematica.detail.field.author".localized(), value: metadata.author.isEmpty ? "common.unknown".localized() : metadata.author)
                        if !metadata.description.isEmpty {
                            infoRow(label: "litematica.detail.field.description".localized(), value: metadata.description, isMultiline: true)
                        }
                    }

                    // 时间信息
                    infoSection(title: "litematica.detail.section.time".localized()) {
                        VStack(alignment: .leading, spacing: 12) {
                            infoRow(label: "litematica.detail.field.created".localized(), value: formatTimestamp(metadata.timeCreated))
                            infoRow(label: "litematica.detail.field.modified".localized(), value: formatTimestamp(metadata.timeModified))
                        }
                    }
                }
                .padding(.vertical, 8)
                .padding(.bottom, 20)

                // 尺寸信息
                infoSection(title: "litematica.detail.section.size".localized()) {
                    VStack(alignment: .leading, spacing: 12) {
                        let hasSize = metadata.enclosingSize.x > 0 || metadata.enclosingSize.y > 0 || metadata.enclosingSize.z > 0
                        if hasSize {
                            infoRow(
                                label: "litematica.detail.field.enclosing_size".localized(),
                                value: "\(metadata.enclosingSize.x) × \(metadata.enclosingSize.y) × \(metadata.enclosingSize.z)"
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
                    }
                }
            }
        }
    }

    private func infoSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
                .padding(.bottom, 10)
            content()
        }
    }

    private func infoRow(label: String, value: String, isMultiline: Bool = false) -> some View {
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

    // MARK: - Footer View
    private var footerView: some View {
        HStack {

            Label {
                Text(filePath.lastPathComponent)
                    .lineLimit(1)
                    .truncationMode(.middle) // 可选：中间省略，长路径更好看
            } icon: {
                Image(systemName: "square.stack.3d.up")
            }
            .font(.caption)
            .foregroundColor(.secondary)
            .frame(maxWidth: 150, alignment: .leading)

            Spacer()

            Label {
                Text(gameName)
                    .lineLimit(1)
                    .truncationMode(.middle) // 可选：中间省略，长路径更好看
            } icon: {
                Image(systemName: "gamecontroller")
            }
            .font(.caption)
            .foregroundColor(.secondary)
            .frame(maxWidth: 300, alignment: .trailing)
        }
    }

    // MARK: - Helper Methods
    private func loadMetadata() async {
        isLoading = true
        errorMessage = nil

        do {
            Logger.shared.debug("开始加载投影详细信息: \(filePath.lastPathComponent)")
            let loadedMetadata = try await LitematicaService.shared.loadFullMetadata(filePath: filePath)
            await MainActor.run {
                if let metadata = loadedMetadata {
                    Logger.shared.debug("成功加载投影元数据: \(metadata.name)")
                    self.metadata = metadata
                } else {
                    Logger.shared.warning("投影元数据为nil: \(filePath.lastPathComponent)")
                    self.errorMessage = "litematica.detail.error.parse_failed".localized()
                }
                self.isLoading = false
            }
        } catch {
            Logger.shared.error("加载投影详细信息失败: \(error.localizedDescription)")
            await MainActor.run {
                self.isLoading = false
                self.errorMessage = String(format: "litematica.detail.error.load_failed".localized(), error.localizedDescription)
                self.showError = true
            }
        }
    }

    private func formatNumber(_ number: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
    }

    private func formatTimestamp(_ timestamp: Int64) -> String {
        guard timestamp > 0 else {
            return "common.unknown".localized()
        }

        let date = Date(timeIntervalSince1970: TimeInterval(timestamp) / 1000.0)
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: date)
    }
}

// MARK: - Preview Helper
struct MetadataContentViewPreview: View {
    let metadata: LitematicMetadata

    var body: some View {
        let sheetView = LitematicaDetailSheetView(filePath: URL(fileURLWithPath: "/tmp/test.litematic"), gameName: "Test Game")
        return sheetView.metadataContentView(metadata: metadata)
    }
}
