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
    
    /// 开始导出整合包（导出到临时位置）
    /// - Parameter gameInfo: 游戏信息
    func startExport(gameInfo: GameVersionInfo) {
        guard exportState == .idle else { return }
        
        // 如果没有设置名称，使用游戏名称
        if modPackName.isEmpty {
            modPackName = gameInfo.gameName
        }
        
        // 重置状态
        exportState = .exporting
        exportProgress = ModPackExporter.ExportProgress()
        exportError = nil
        tempExportPath = nil
        hasShownSaveDialog = false
        saveError = nil
        
        // 创建临时文件路径
        let tempDir = FileManager.default.temporaryDirectory
        let tempFileName = "\(modPackName).mrpack"
        let tempPath = tempDir.appendingPathComponent(tempFileName)
        
        exportTask = Task {
            let result = await ModPackExporter.exportModPack(
                gameInfo: gameInfo,
                outputPath: tempPath,
                modPackName: modPackName,
                modPackVersion: modPackVersion,
                summary: nil
            ) { progress in
                Task { @MainActor in
                    self.exportProgress = progress
                }
            }
            
            await MainActor.run {
                if result.success {
                    // 导出成功，设置为完成状态并保存临时文件路径（触发保存对话框）
                    // ModPackExporter 已经通过 progressCallback 更新了最终进度（100%），
                    // 这里不需要重复处理进度条逻辑
                    self.exportState = .completed
                    self.tempExportPath = result.outputPath
                    Logger.shared.info("整合包导出到临时位置成功: \(result.outputPath?.path ?? "未知路径")")
                } else {
                    // 导出失败，清理临时文件并回到空闲状态
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
    
    /// 处理文件保存成功
    func handleSaveSuccess() {
        tempExportPath = nil
        hasShownSaveDialog = false
        saveError = nil
        exportState = .idle
        exportProgress = ModPackExporter.ExportProgress()
    }
    
    /// 处理文件保存失败
    /// - Parameter error: 错误信息
    func handleSaveFailure(error: String) {
        saveError = error
        // 保存失败时，清理临时文件
        cleanupTempFile()
        hasShownSaveDialog = false
    }
    
    /// 处理用户取消保存
    func handleSaveCancelled() {
        cleanupTempFile()
        hasShownSaveDialog = false
        saveError = nil
        exportState = .idle
        exportProgress = ModPackExporter.ExportProgress()
    }
    
    // MARK: - Reset Actions
    
    /// 重置所有状态
    func reset() {
        cancelExport()
        modPackName = ""
        modPackVersion = "1.0.0"
        summary = ""
    }
    
    /// 清理所有整合包导出相关的数据和临时文件
    /// 在页面关闭时调用
    func cleanupAllData() {
        // 取消导出任务
        exportTask?.cancel()
        exportTask = nil
        
        // 清理临时文件
        cleanupTempFile()
        cleanupTempDirectories()
        
        // 重置所有状态
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
    
    /// 清理临时文件
    private func cleanupTempFile() {
        if let tempPath = tempExportPath {
            do {
                if FileManager.default.fileExists(atPath: tempPath.path) {
                    try FileManager.default.removeItem(at: tempPath)
                    Logger.shared.info("已清理临时文件: \(tempPath.path)")
                }
            } catch {
                Logger.shared.warning("清理临时文件失败: \(error.localizedDescription)")
            }
        }
        tempExportPath = nil
    }
    
    /// 清理临时目录（modpack_export 目录）
    private func cleanupTempDirectories() {
        let tempBaseDir = FileManager.default.temporaryDirectory
        let exportDir = tempBaseDir.appendingPathComponent("modpack_export")
        
        if FileManager.default.fileExists(atPath: exportDir.path) {
            do {
                try FileManager.default.removeItem(at: exportDir)
                Logger.shared.info("已清理临时导出目录: \(exportDir.path)")
            } catch {
                Logger.shared.warning("清理临时导出目录失败: \(error.localizedDescription)")
            }
        }
    }
}

