//
//  ModPackExportViewModel.swift
//  SwiftCraftLauncher
//
//  Created by Auto on 2025/01/XX.
//

import Foundation
import SwiftUI

/// 整合包导出视图模型
/// 管理整合包导出流程的状态和业务逻辑
@MainActor
class ModPackExportViewModel: ObservableObject {
    // MARK: - Export State

    /// 导出状态枚举
    enum ExportState: Equatable {
        case idle              // 空闲状态，显示表单
        case exporting         // 正在导出，显示进度
        case completed         // 导出完成，等待保存，显示进度（100%）
    }

    // MARK: - Published Properties

    /// 导出状态
    @Published var exportState: ExportState = .idle

    /// 导出进度信息
    @Published var exportProgress = ModPackExporter.ExportProgress()

    /// 整合包名称
    @Published var modPackName: String = ""

    /// 整合包版本
    @Published var modPackVersion: String = "1.0.0"

    /// 整合包描述
    @Published var summary: String = ""

    /// 导出错误信息
    @Published var exportError: String?

    /// 临时文件路径，当有值时表示打包完成，需要显示保存对话框
    @Published var tempExportPath: URL?

    /// 保存文件时的错误信息
    @Published var saveError: String?

    // MARK: - Private Properties

    /// 导出任务
    private var exportTask: Task<Void, Never>?

    /// 是否已显示保存对话框（防止重复显示）
    private var hasShownSaveDialog = false

    // MARK: - Computed Properties

    /// 是否正在导出
    var isExporting: Bool {
        exportState == .exporting
    }

    /// 是否应该显示保存对话框
    var shouldShowSaveDialog: Bool {
        tempExportPath != nil && !hasShownSaveDialog
    }

    // MARK: - Export Actions

    func startExport(gameInfo: GameVersionInfo) {
        guard exportState == .idle else { return }

        if modPackName.isEmpty {
            modPackName = gameInfo.gameName
        }

        exportState = .exporting
        exportProgress = ModPackExporter.ExportProgress()
        exportError = nil
        tempExportPath = nil
        hasShownSaveDialog = false
        saveError = nil

        let tempPath = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(modPackName).mrpack")

        exportTask = Task {
            let result = await ModPackExporter.exportModPack(
                gameInfo: gameInfo,
                outputPath: tempPath,
                modPackName: modPackName,
                modPackVersion: modPackVersion,
                summary: summary.isEmpty ? nil : summary
            ) { progress in
                Task { @MainActor in
                    self.exportProgress = progress
                }
            }

            await MainActor.run {
                if result.success {
                    self.exportState = .completed
                    self.tempExportPath = result.outputPath
                    Logger.shared.info("整合包导出到临时位置成功: \(result.outputPath?.path ?? "未知路径")")
                } else {
                    self.cleanupTempFile()
                    self.exportState = .idle
                    self.exportError = result.message
                    self.exportProgress = ModPackExporter.ExportProgress()
                    Logger.shared.error("整合包导出失败: \(result.message)")
                }
            }
        }
    }

    /// 取消导出任务
    func cancelExport() {
        exportTask?.cancel()
        cleanupTempFile()
        exportState = .idle
        exportProgress = ModPackExporter.ExportProgress()
        exportError = nil
        hasShownSaveDialog = false
        saveError = nil
    }

    // MARK: - Save Dialog Actions

    /// 标记保存对话框已显示（防止重复显示）
    func markSaveDialogShown() {
        hasShownSaveDialog = true
    }

    func handleSaveSuccess() {
        cleanupTempFile()
        hasShownSaveDialog = false
        saveError = nil
        exportState = .idle
        exportProgress = ModPackExporter.ExportProgress()
    }

    func handleSaveFailure(error: String) {
        saveError = error
        cleanupTempFile()
        hasShownSaveDialog = false
    }

    func cleanupAllData() {
        exportTask?.cancel()
        exportTask = nil
        cleanupTempFile()
        cleanupTempDirectories()
        exportState = .idle
        exportProgress = ModPackExporter.ExportProgress()
        exportError = nil
        tempExportPath = nil
        hasShownSaveDialog = false
        saveError = nil
        modPackName = ""
        modPackVersion = "1.0.0"
        summary = ""
    }

    // MARK: - Private Helper Methods

    private func cleanupTempFile() {
        guard let tempPath = tempExportPath else { return }
        do {
            if FileManager.default.fileExists(atPath: tempPath.path) {
                try FileManager.default.removeItem(at: tempPath)
                Logger.shared.info("已清理临时文件: \(tempPath.path)")
            }
        } catch {
            Logger.shared.warning("清理临时文件失败: \(error.localizedDescription)")
        }
        tempExportPath = nil
    }

    private func cleanupTempDirectories() {
        let exportDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("modpack_export")
        guard FileManager.default.fileExists(atPath: exportDir.path) else { return }
        do {
            try FileManager.default.removeItem(at: exportDir)
            Logger.shared.info("已清理临时导出目录: \(exportDir.path)")
        } catch {
            Logger.shared.warning("清理临时导出目录失败: \(error.localizedDescription)")
        }
    }
}
