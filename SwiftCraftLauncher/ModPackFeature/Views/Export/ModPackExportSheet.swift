//
//  ModPackExportSheet.swift
//  ModPackFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import SwiftUI

/// A sheet for exporting a game profile as a modpack.
struct ModPackExportSheet: View {
    let gameInfo: GameVersionInfo
    @Environment(\.dismiss)
    private var dismiss
    @State private var viewModel: ModPackExportViewModel
    @State private var saveModel = ModPackExportSaveModel()
    @FocusState private var isSummaryFocused: Bool

    init(gameInfo: GameVersionInfo) {
        self.gameInfo = gameInfo
        _viewModel = State(wrappedValue: ModPackExportViewModel())
    }

    var body: some View {
        CommonSheetView(
            header: { headerView },
            body: { bodyView },
            footer: { footerView },
        )
        .modifier(
            ModPackFileExporter(
                isPresented: $saveModel.isExporterPresented,
                prepared: saveModel.prepared,
                onCompletion: handleSaveCompletion,
            ) {
                saveModel.cleanup()
                viewModel.handleSaveCancellation()
            },
        )
        .onDisappear {
            viewModel.cleanupAllData()
            saveModel.cleanup()
        }
        .onChange(of: viewModel.shouldShowSaveDialog) { _, shouldShow in
            if shouldShow, let tempPath = viewModel.completedExportPath {
                handleExportCompleted(tempFilePath: tempPath)
            }
        }
    }

    private var headerView: some View {
        HStack(alignment: .center, spacing: 12) {
            Text("modpack.export.title".localized())
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            Menu {
                ForEach(ModPackExportFormat.allCases, id: \.self) { format in
                    Button(format.displayName) {
                        viewModel.currentExportFormat = format
                    }
                }
            } label: {
                Text(viewModel.currentExportFormat.displayName)
            }
            .disabled(viewModel.exportState != .idle)
            .fixedSize()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var bodyView: some View {
        VStack(alignment: .leading, spacing: 16) {
            if viewModel.exportState == .idle, let error = viewModel.exportError {
                errorView(error: error)
            } else {
                exportFormView
            }

            if viewModel.exportState == .exporting || viewModel.exportState == .completed,
               viewModel.exportProgress.scanProgress != nil || viewModel.exportProgress.copyProgress != nil {
                progressItemsView
                    .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var exportFormView: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("modpack.version".localized())
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                TextField("modpack.export.version.placeholder".localized(), text: $viewModel.modPackVersion)
                    .textFieldStyle(.roundedBorder)
                    .focusable(false)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("modpack.export.summary".localized())
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                TextField("modpack.export.summary.placeholder".localized(), text: $viewModel.summary)
                    .textFieldStyle(.roundedBorder)
                    .focused($isSummaryFocused)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("version.directory.tree".localized())
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                FileTreeView(
                    rootURL: AppPaths.profileDirectory(gameName: gameInfo.gameName),
                ) { urls in
                    viewModel.selectedFileURLs = urls
                }
                .frame(maxWidth: .infinity)
                .frame(height: 300)
            }
        }
    }

    private var footerView: some View {
        HStack {
            Button("common.cancel".localized()) {
                if viewModel.exportState == .idle {
                    dismiss()
                } else {
                    viewModel.cancelExport()
                    saveModel.cleanup()
                }
            }
            .keyboardShortcut(.cancelAction)

            Spacer()

            Button {
                isSummaryFocused = false
                if let tempPath = viewModel.completedExportPath {
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

    private var progressItemsView: some View {
        VStack(spacing: 16) {
            if let scanProgress = viewModel.exportProgress.scanProgress {
                progressRow(progress: scanProgress)
                    .id("scan-\(scanProgress.completed)-\(scanProgress.total)")
            }

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
                version: nil,
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

    private func handleExportCompleted(tempFilePath: URL) {
        if viewModel.shouldShowSaveDialog {
            viewModel.markSaveDialogShown()
        }

        saveModel.prepare(
            PreparedModPackArchive(
                fileURL: tempFilePath,
                format: viewModel.currentExportFormat,
            ),
        )
    }

    private func handleSaveCompletion(_ result: Result<URL, Error>) {
        saveModel.cleanup()

        switch result {
        case let .success(url):
            AppLog.modPack.info("Modpack saved to: \(url.path)")
            viewModel.handleSaveSuccess()
            dismiss()
        case let .failure(error):
            let nsError = error as NSError
            if error is CancellationError || nsError.code == NSUserCancelledError {
                viewModel.handleSaveCancellation()
                return
            }
            AppLog.modPack.error("Failed to save file: \(error.localizedDescription)")
            viewModel.handleSaveFailure(error: error.localizedDescription)
        }
    }
}
