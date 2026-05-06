//
//  ModPackExportSheet.swift
//  SwiftCraftLauncher
//
//  Created by Auto on 2025/01/XX.
//

import SwiftUI
import UniformTypeIdentifiers

/// 整合包文档类型，用于文件导出
struct ModPackDocument: FileDocument {
    static var readableContentTypes: [UTType] {
        [
            UTType(filenameExtension: AppConstants.FileExtensions.mrpack) ?? UTType.zip,
            UTType.zip,
        ]
    }

    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

/// 整合包导出 Sheet 视图
/// 提供整合包导出功能，包括：
/// - 导出表单（名称、版本、描述）
/// - 导出进度显示
/// - 导出完成提示
/// - 文件保存对话框
struct ModPackExportSheet: View {
    // MARK: - Properties
    let gameInfo: GameVersionInfo
    @Environment(\.dismiss)
    private var dismiss
    @StateObject private var viewModel: ModPackExportViewModel
    @State private var showSaveErrorAlert = false
    @StateObject private var coordinator = ModPackExportSheetCoordinatorViewModel()

    // MARK: - Initialization
    init(gameInfo: GameVersionInfo) {
        self.gameInfo = gameInfo
        let viewModel = ModPackExportViewModel()
        // 导出包名固定使用当前游戏名
        viewModel.modPackName = gameInfo.gameName
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    // MARK: - Body
    var body: some View {
        CommonSheetView(
            header: { headerView },
            body: { bodyView },
            footer: { footerView }
        )
        .onDisappear {
            viewModel.cleanupAllData()
        }
        .onChange(of: viewModel.shouldShowSaveDialog) { _, shouldShow in
            if shouldShow, let tempPath = viewModel.tempExportPath {
                handleExportCompleted(tempFilePath: tempPath)
            }
        }
        .onChange(of: coordinator.isExporting) { oldValue, newValue in
            coordinator.cleanupExporterStateIfNeeded(oldValue: oldValue, newValue: newValue)
        }
        .fileExporter(
            isPresented: $coordinator.isExporting,
            document: coordinator.exportDocument,
            contentType: exportContentType,
            defaultFilename: exportDefaultFilename
        ) { result in
            switch result {
            case .success(let url):
                Logger.shared.info("整合包已保存到: \(url.path)")
                viewModel.handleSaveSuccess()
                dismiss()
            case .failure(let error):
                Logger.shared.error("保存文件失败: \(error.localizedDescription)")
                viewModel.handleSaveFailure(error: error.localizedDescription)
            }
            coordinator.reset()
        }
        .alert("common.error".localized(), isPresented: $showSaveErrorAlert) {
            Button("common.ok".localized(), role: .cancel) {
                viewModel.saveError = nil
            }
        } message: {
            if let error = viewModel.saveError {
                Text(error)
            }
        }
        .onChange(of: viewModel.saveError) { _, error in
            showSaveErrorAlert = error != nil
        }
    }

    private var headerView: some View {
        HStack(alignment: .center, spacing: 12) {
            Text("modpack.export.title".localized())
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            CommonMenuPicker(
                selection: $viewModel.currentExportFormat,
                hidesLabel: true
            ) {
                Text("")
            } content: {
                ForEach(ModPackExportFormat.allCases, id: \.self) { format in
                    Text(paddedPickerLabel(format.displayName)).tag(format)
                }
            }
            .disabled(viewModel.isExporting)
        }
    }

    @ViewBuilder private var bodyView: some View {
        switch viewModel.exportState {
        case .idle:
            idleStateView
                .frame(maxWidth: .infinity, alignment: .topLeading)
        case .exporting, .completed:
            exportProgressView
        }
    }

    // MARK: - State Views

    @ViewBuilder private var idleStateView: some View {
        if let error = viewModel.exportError {
            errorView(error: error)
        } else {
            exportFormView
        }
    }

    private var exportFormView: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 整合包版本
            VStack(alignment: .leading, spacing: 8) {
                Text("modpack.export.version".localized())
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                TextField("modpack.export.version.placeholder".localized(), text: $viewModel.modPackVersion)
                    .textFieldStyle(.roundedBorder)
                    .focusable(false)
            }

            // 整合包描述（Summary）
            VStack(alignment: .leading, spacing: 8) {
                Text("modpack.export.summary".localized())
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                TextField("modpack.export.summary.placeholder".localized(), text: $viewModel.summary)
                    .textFieldStyle(.roundedBorder)
            }

            // 版本目录
            VStack(alignment: .leading, spacing: 8) {
                Text("version.directory.tree".localized())
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                FileTreeView(
                    rootURL: AppPaths.profileDirectory(gameName: gameInfo.gameName)
                ) { urls in
                    if viewModel.selectedFileURLs != urls {
                        DispatchQueue.main.async {
                            viewModel.selectedFileURLs = urls
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 300)
            }
        }
    }

    private var exportProgressView: some View {
        VStack(alignment: .leading, spacing: 16) {
            exportFormView
            if viewModel.exportProgress.scanProgress != nil || viewModel.exportProgress.copyProgress != nil {
                progressItemsView
                    .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var footerView: some View {
        HStack {
            Button("common.cancel".localized()) {
                if viewModel.isExporting {
                    coordinator.reset()
                    viewModel.cancelExport()
                    viewModel.resetToInitial(gameInfo: gameInfo)
                } else {
                    dismiss()
                }
            }
            .keyboardShortcut(.cancelAction)

            Spacer()

            Button {
                if viewModel.exportState == .completed, let tempPath = viewModel.tempExportPath {
                    handleExportCompleted(tempFilePath: tempPath)
                } else {
                    viewModel.startExport(gameInfo: gameInfo)
                }
            } label: {
                if viewModel.isExporting {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Text("modpack.export.button".localized())
                }
            }
            .keyboardShortcut(.defaultAction)
            .disabled(viewModel.isExporting)
        }
    }

    private var exportContentType: UTType {
        switch viewModel.currentExportFormat {
        case .modrinth:
            return UTType(filenameExtension: AppConstants.FileExtensions.mrpack) ?? UTType.zip
        case .curseforge:
            return UTType.zip
        }
    }

    private var exportDefaultFilename: String {
        "\(gameInfo.gameName).\(viewModel.currentExportFormat.fileExtension)"
    }

    // MARK: - Reusable Components

    private var progressItemsView: some View {
        VStack(spacing: 16) {
            // 扫描资源进度条
            if let scanProgress = viewModel.exportProgress.scanProgress {
                progressRow(progress: scanProgress)
                    .id("scan-\(scanProgress.completed)-\(scanProgress.total)")
            }

            // 复制文件进度条
            if let copyProgress = viewModel.exportProgress.copyProgress {
                progressRow(progress: copyProgress)
                    .id("copy-\(copyProgress.completed)-\(copyProgress.total)")
            }
        }
    }

    private func progressRow(progress: ModPackExporter.ExportProgress.ProgressItem) -> some View {
        FormSection {
            DownloadProgressRow(
                title: progress.title,
                progress: progress.progress,
                currentFile: progress.currentFile,
                completed: progress.completed,
                total: progress.total,
                version: nil
            )
        }
        .frame(minHeight: 70)
    }

    private func errorView(error: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "xmark.circle.fill")
                .foregroundColor(.red)
                .font(.system(size: 48))

            Text("modpack.export.failed".localized())
                .font(.headline)

            Text(error)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity)
    }

    // MARK: - Actions

    /// 处理导出完成，显示保存对话框
    private func handleExportCompleted(tempFilePath: URL) {
        if viewModel.shouldShowSaveDialog {
            viewModel.markSaveDialogShown()
        }
        coordinator.prepareExportDocument(from: tempFilePath) { errorMessage in
            Logger.shared.error("读取临时文件失败: \(errorMessage)")
            viewModel.handleSaveFailure(error: errorMessage)
        }
    }
}
