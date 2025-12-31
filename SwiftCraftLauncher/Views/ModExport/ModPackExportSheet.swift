//
//  ModPackExportSheet.swift
//  SwiftCraftLauncher
//
//  Created by Auto on 2025/01/XX.
//

import SwiftUI
import AppKit

/// 整合包导出 Sheet 视图
/// 提供整合包导出功能，包括：
/// - 导出表单（名称、版本、描述）
/// - 导出进度显示
/// - 导出完成提示
/// - 文件保存对话框
struct ModPackExportSheet: View {
    // MARK: - Properties
    let gameInfo: GameVersionInfo
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = ModPackExportViewModel()
    @State private var showSaveErrorAlert = false
    
    // MARK: - Body
    var body: some View {
        CommonSheetView(
            header: { headerView },
            body: { bodyView },
            footer: { footerView }
        )
        .onAppear {
            initializeDefaults()
        }
        .onDisappear {
            // 页面关闭后清理所有数据和临时文件
            viewModel.cleanupAllData()
        }
        .onChange(of: viewModel.shouldShowSaveDialog) { shouldShow in
            if shouldShow, let tempPath = viewModel.tempExportPath {
                handleExportCompleted(tempFilePath: tempPath)
            }
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
        .onChange(of: viewModel.saveError) { error in
            showSaveErrorAlert = error != nil
        }
    }
    
    private var headerView: some View {
        HStack {
            Text("modpack.export.title".localized())
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    private var bodyView: some View {
        Group {
            switch viewModel.exportState {
            case .idle:
                idleStateView
            case .exporting, .completed:
                // 完成时继续显示进度视图，直接弹出保存对话框
                exportProgressView
            }
        }
        .frame(maxWidth: .infinity,alignment: .topLeading)
    }
    
    // MARK: - State Views
    
    private var idleStateView: some View {
        Group {
            if let error = viewModel.exportError {
                errorView(error: error)
            } else {
                exportFormView
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
    
    private var exportFormView: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 整合包名称
            VStack(alignment: .leading, spacing: 8) {
                Text("modpack.export.name".localized())
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                TextField("modpack.export.name.placeholder".localized(), text: $viewModel.modPackName)
                    .textFieldStyle(.roundedBorder)
            }
            
            // 整合包版本
            VStack(alignment: .leading, spacing: 8) {
                Text("modpack.export.version".localized())
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                TextField("modpack.export.version.placeholder".localized(), text: $viewModel.modPackVersion)
                    .textFieldStyle(.roundedBorder)
            }
        }
    }
    
    private var exportProgressView: some View {
        VStack(alignment: .leading, spacing: 16) {
            exportFormView
            progressItemsView
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
    
    private var footerView: some View {
        HStack {
            Button("common.cancel".localized()) {
                if viewModel.isExporting {
                    viewModel.cancelExport()
                }
                dismiss()
            }
            .keyboardShortcut(.cancelAction)
            
            Spacer()
            
            Button("modpack.export.button".localized()) {
                viewModel.startExport(gameInfo: gameInfo)
            }
            .keyboardShortcut(.defaultAction)
            .disabled(viewModel.modPackName.isEmpty || viewModel.isExporting)
        }
    }
    
    // MARK: - Reusable Components
    
    /// 进度项视图（用于导出中和完成状态）
    private var progressItemsView: some View {
        VStack(spacing: 16) {
            // 扫描资源进度条（总是显示，因为扫描是必然的）
            if let scanProgress = viewModel.exportProgress.scanProgress {
                progressRow(progress: scanProgress)
                    .id("scan-\(scanProgress.completed)-\(scanProgress.total)")
            }
            
            // 复制文件进度条（只在有复制任务时显示，不显示占位符）
            if let copyProgress = viewModel.exportProgress.copyProgress {
                progressRow(progress: copyProgress)
                    .id("copy-\(copyProgress.completed)-\(copyProgress.total)")
            }
        }
    }
    
    /// 单个进度行（固定最小高度，保持布局稳定）
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
    
    /// 初始化默认值
    private func initializeDefaults() {
        if viewModel.modPackName.isEmpty {
            viewModel.modPackName = gameInfo.gameName
        }
    }
    
    /// 处理导出完成，直接显示保存对话框
    /// - Parameter tempFilePath: 临时文件路径
    private func handleExportCompleted(tempFilePath: URL) {
        viewModel.markSaveDialogShown()
        // 直接显示保存对话框，不延迟
        showSavePanel(tempFilePath: tempFilePath)
    }
    
    /// 显示保存对话框并处理文件保存
    /// - Parameter tempFilePath: 临时文件路径
    private func showSavePanel(tempFilePath: URL) {
        let savePanel = createSavePanel()
        let modPackName = viewModel.modPackName
        savePanel.begin { response in
            if response == .OK, let directoryURL = savePanel.url {
                self.handleSaveFile(
                    from: tempFilePath,
                    to: directoryURL,
                    fileName: "\(modPackName).mrpack"
                )
            } else {
                self.handleSaveCancelled(tempFilePath: tempFilePath)
            }
        }
    }
    
    /// 创建保存面板
    private func createSavePanel() -> NSOpenPanel {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        return panel
    }
    
    /// 处理文件保存
    /// - Parameters:
    ///   - sourceURL: 源文件路径
    ///   - directoryURL: 目标目录
    ///   - fileName: 文件名
    private func handleSaveFile(from sourceURL: URL, to directoryURL: URL, fileName: String) {
        let destinationURL = directoryURL.appendingPathComponent(fileName)
        
        do {
            // 如果目标文件已存在，先删除
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            
            // 移动文件
            try FileManager.default.moveItem(at: sourceURL, to: destinationURL)
            
            Logger.shared.info("整合包已保存到: \(destinationURL.path)")
            viewModel.handleSaveSuccess()
            dismiss()
        } catch {
            Logger.shared.error("保存文件失败: \(error.localizedDescription)")
            viewModel.handleSaveFailure(error: error.localizedDescription)
        }
    }
    
    /// 处理用户取消保存
    /// - Parameter tempFilePath: 临时文件路径（已不再使用，保留以保持接口兼容）
    private func handleSaveCancelled(tempFilePath: URL) {
        // ViewModel 负责清理临时文件
        viewModel.handleSaveCancelled()
    }
}

