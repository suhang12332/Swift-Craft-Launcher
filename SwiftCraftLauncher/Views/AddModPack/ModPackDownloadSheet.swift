//
//  ModPackDownloadSheet.swift
//  SwiftCraftLauncher
//
//  Created by su on 2025/8/2.
//

import SwiftUI

struct ModPackDownloadSheet: View {
   let projectId: String
   let gameInfo: GameVersionInfo?
   let query: String
   @EnvironmentObject private var gameRepository: GameRepository
   @Environment(\.dismiss) private var dismiss
   
   @StateObject private var viewModel = ModPackDownloadSheetViewModel()
   @State private var selectedGameVersion: String = ""
   @State private var selectedModPackVersion: ModrinthProjectDetailVersion?
   @State private var downloadTask: Task<Void, Error>? = nil
   @State private var isProcessing = false // 下载和解析阶段
   @StateObject private var gameSetupService = GameSetupUtil()
   
   var body: some View {
       CommonSheetView(
           header: {
               HStack {
                   Text("modpack.download.title".localized())
                       .font(.headline)
                       .frame(maxWidth: .infinity, alignment: .leading)
               }
           },
           body: {
               VStack(spacing: 20) {
                   if isProcessing {
                       processingView
                   } else if let projectDetail = viewModel.projectDetail {
                       ModrinthProjectTitleView(projectDetail: projectDetail)
                           .padding(.bottom, 24)
                       
                       versionSelectionSection
                       
                       if shouldShowProgress {
                           downloadProgressSection
                       }
                   }
               }
           },
           footer: {
               HStack {
                   cancelButton
                   Spacer()
                   confirmButton
               }
           }
       )
       .onAppear {
           viewModel.setGameRepository(gameRepository)
           Task {
               await viewModel.loadProjectDetails(projectId: projectId)
           }
       }
   }
   
   // MARK: - Computed Properties
   
   private var shouldShowProgress: Bool {
       gameSetupService.downloadState.isDownloading || viewModel.modPackInstallState.isInstalling
   }
   
   private var canDownload: Bool {
       !selectedGameVersion.isEmpty && selectedModPackVersion != nil
   }
   
   private var isDownloading: Bool {
       isProcessing || gameSetupService.downloadState.isDownloading || viewModel.modPackInstallState.isInstalling
   }
   
   // MARK: - Processing View
   
   private var processingView: some View {
       VStack(spacing: 24) {
           ProgressView()
               .scaleEffect(1.5)
               .padding(.bottom, 16)
           
           Text("modpack.processing.title".localized())
               .font(.headline)
               .foregroundColor(.primary)
           
           Text("modpack.processing.subtitle".localized())
               .font(.subheadline)
               .foregroundColor(.secondary)
               .multilineTextAlignment(.center)
           
           Spacer()
       }
       .frame(maxWidth: .infinity, maxHeight: .infinity)
       .padding()
   }
   
   // MARK: - Download Progress Section
   
   private var downloadProgressSection: some View {
       VStack(spacing: 24) {
           // 游戏下载进度
           gameDownloadProgress
           
           // 模组加载器下载进度
           modLoaderDownloadProgress
           
           // 整合包安装进度
           modPackInstallProgress
       }
   }
   
   private var gameDownloadProgress: some View {
       Group {
           FormSection {
               DownloadProgressRow(
                   title: "download.core.title".localized(),
                   progress: gameSetupService.downloadState.coreProgress,
                   currentFile: gameSetupService.downloadState.currentCoreFile,
                   completed: gameSetupService.downloadState.coreCompletedFiles,
                   total: gameSetupService.downloadState.coreTotalFiles,
                   version: nil
               )
           }
           FormSection {
               DownloadProgressRow(
                   title: "download.resources.title".localized(),
                   progress: gameSetupService.downloadState.resourcesProgress,
                   currentFile: gameSetupService.downloadState.currentResourceFile,
                   completed: gameSetupService.downloadState.resourcesCompletedFiles,
                   total: gameSetupService.downloadState.resourcesTotalFiles,
                   version: nil
               )
           }
       }
   }
   
   private var modLoaderDownloadProgress: some View {
       Group {
           if let indexInfo = viewModel.lastParsedIndexInfo {
               switch indexInfo.loaderType.lowercased() {
               case "fabric", "quilt":
                   FormSection {
                       DownloadProgressRow(
                           title: indexInfo.loaderType.lowercased() == "fabric"
                               ? "fabric.loader.title".localized()
                               : "quilt.loader.title".localized(),
                           progress: gameSetupService.fabricDownloadState.coreProgress,
                           currentFile: gameSetupService.fabricDownloadState.currentCoreFile,
                           completed: gameSetupService.fabricDownloadState.coreCompletedFiles,
                           total: gameSetupService.fabricDownloadState.coreTotalFiles,
                           version: indexInfo.loaderVersion
                       )
                   }
               case "forge":
                   FormSection {
                       DownloadProgressRow(
                           title: "forge.loader.title".localized(),
                           progress: gameSetupService.forgeDownloadState.coreProgress,
                           currentFile: gameSetupService.forgeDownloadState.currentCoreFile,
                           completed: gameSetupService.forgeDownloadState.coreCompletedFiles,
                           total: gameSetupService.forgeDownloadState.coreTotalFiles,
                           version: indexInfo.loaderVersion
                       )
                   }
               case "neoforge":
                   FormSection {
                       DownloadProgressRow(
                           title: "neoforge.loader.title".localized(),
                           progress: gameSetupService.neoForgeDownloadState.coreProgress,
                           currentFile: gameSetupService.neoForgeDownloadState.currentCoreFile,
                           completed: gameSetupService.neoForgeDownloadState.coreCompletedFiles,
                           total: gameSetupService.neoForgeDownloadState.coreTotalFiles,
                           version: indexInfo.loaderVersion
                       )
                   }
               default:
                   EmptyView()
               }
           }
       }
   }
   
   private var modPackInstallProgress: some View {
       Group {
           if viewModel.modPackInstallState.isInstalling {
               FormSection {
                   DownloadProgressRow(
                       title: "modpack.files.title".localized(),
                       progress: viewModel.modPackInstallState.filesProgress,
                       currentFile: viewModel.modPackInstallState.currentFile,
                       completed: viewModel.modPackInstallState.filesCompleted,
                       total: viewModel.modPackInstallState.filesTotal,
                       version: nil
                   )
               }
               // 只有当依赖数量大于0时才显示依赖进度条
               if viewModel.modPackInstallState.dependenciesTotal > 0 {
                   FormSection {
                       DownloadProgressRow(
                           title: "modpack.dependencies.title".localized(),
                           progress: viewModel.modPackInstallState.dependenciesProgress,
                           currentFile: viewModel.modPackInstallState.currentDependency,
                           completed: viewModel.modPackInstallState.dependenciesCompleted,
                           total: viewModel.modPackInstallState.dependenciesTotal,
                           version: nil
                       )
                   }
               }
               if viewModel.modPackInstallState.overridesTotal > 0 {
                   FormSection {
                       DownloadProgressRow(
                           title: "modpack.overrides.title".localized(),
                           progress: viewModel.modPackInstallState.overridesProgress,
                           currentFile: viewModel.modPackInstallState.currentOverride,
                           completed: viewModel.modPackInstallState.overridesCompleted,
                           total: viewModel.modPackInstallState.overridesTotal,
                           version: nil
                       )
                   }
               }
           }
       }
   }
   
   // MARK: - Version Selection Section
   
   private var versionSelectionSection: some View {
       VStack(alignment: .leading, spacing: 16) {
           gameVersionPicker
           modPackVersionPicker
       }
   }
   
   private var gameVersionPicker: some View {
       Picker("modpack.game.version".localized(), selection: $selectedGameVersion) {
           Text("modpack.game.version.placeholder".localized()).tag("")
           ForEach(viewModel.availableGameVersions, id: \.self) { version in
               Text(version).tag(version)
           }
       }
       .pickerStyle(MenuPickerStyle())
       .onChange(of: selectedGameVersion) { old, newValue in
           handleGameVersionChange(newValue)
       }
   }
   
   private var modPackVersionPicker: some View {
       VStack(alignment: .leading, spacing: 8) {
           if viewModel.isLoadingModPackVersions {
               HStack {
                   ProgressView()
                       .controlSize(.small)
               }
           } else if !selectedGameVersion.isEmpty {
               Picker("modpack.version".localized(), selection: $selectedModPackVersion) {
                   ForEach(viewModel.filteredModPackVersions, id: \.id) { version in
                       Text(version.name).tag(version as ModrinthProjectDetailVersion?)
                   }
               }
               .pickerStyle(MenuPickerStyle())
               .onAppear {
                   selectFirstModPackVersion()
               }
           }
       }
   }
   
   // MARK: - Footer Buttons
   
   private var cancelButton: some View {
       Button("common.cancel".localized()) {
           handleCancel()
       }
       .keyboardShortcut(.cancelAction)
   }
   
   private var confirmButton: some View {
       Button {
           Task {
               await downloadModPack()
           }
       } label: {
           HStack {
               if isDownloading {
                   ProgressView()
                       .controlSize(.small)
               } else {
                   Text("modpack.download.button".localized())
               }
           }
       }
       .keyboardShortcut(.defaultAction)
       .disabled(!canDownload || isDownloading)
   }
   
   // MARK: - Helper Methods
   
   private func handleGameVersionChange(_ newValue: String) {
       if !newValue.isEmpty {
           Task {
               await viewModel.loadModPackVersions(for: newValue)
           }
       } else {
           viewModel.filteredModPackVersions = []
       }
   }
   
   private func selectFirstModPackVersion() {
       if !viewModel.filteredModPackVersions.isEmpty && selectedModPackVersion == nil {
           selectedModPackVersion = viewModel.filteredModPackVersions[0]
       }
   }
   
   private func handleCancel() {
       if isDownloading {
           downloadTask?.cancel()
           downloadTask = nil
           isProcessing = false
           viewModel.modPackInstallState.reset()
       } else {
           dismiss()
       }
   }
   
   // MARK: - Download Action
   
   @MainActor
   private func downloadModPack() async {
       guard let selectedVersion = selectedModPackVersion,
             let projectDetail = viewModel.projectDetail else { return }
       
       downloadTask = Task {
           await performModPackDownload(selectedVersion: selectedVersion, projectDetail: projectDetail)
       }
   }
   
   @MainActor
   private func performModPackDownload(
       selectedVersion: ModrinthProjectDetailVersion,
       projectDetail: ModrinthProjectDetail
   ) async {
       // 开始处理阶段
       isProcessing = true
       
//       defer {
//           isProcessing = false
//       }
       
       // 1. 下载整合包
       guard let downloadedPath = await downloadModPackFile(selectedVersion: selectedVersion, projectDetail: projectDetail) else {
           return
       }
       
       // 2. 解压整合包
       guard let extractedPath = await viewModel.extractModPack(modPackPath: downloadedPath) else {
           return
       }
       
       // 3. 解析 modrinth.index.json
       guard let indexInfo = await viewModel.parseModrinthIndex(extractedPath: extractedPath) else {
           return
       }
       
       // 4. 下载游戏图标
       let gameName = "\(projectDetail.title)-\(selectedGameVersion)"
       let iconPath = await viewModel.downloadGameIcon(
           projectDetail: projectDetail,
           gameName: gameName
       )
       isProcessing = false
       
       // 5. 创建游戏配置并安装依赖
       await createGameAndInstallDependencies(
           gameName: gameName,
           iconPath: iconPath,
           indexInfo: indexInfo,
           extractedPath: extractedPath
       )
   }
   
   private func downloadModPackFile(
       selectedVersion: ModrinthProjectDetailVersion,
       projectDetail: ModrinthProjectDetail
   ) async -> URL? {
       let primaryFile = selectedVersion.files.first { $0.primary } ?? selectedVersion.files.first
       
       guard let fileToDownload = primaryFile else {
           let globalError = GlobalError.resource(
               chineseMessage: "没有找到可下载的文件",
               i18nKey: "error.resource.no_downloadable_file",
               level: .notification
           )
           GlobalErrorHandler.shared.handle(globalError)
           return nil
       }
       
       return await viewModel.downloadModPackFile(
           file: fileToDownload,
           projectDetail: projectDetail
       )
   }
   
   private func createGameAndInstallDependencies(
       gameName: String,
       iconPath: String?,
       indexInfo: ModrinthIndexInfo,
       extractedPath: URL
   ) async {
       await gameSetupService.saveGame(
           gameName: gameName,
           gameIcon: iconPath ?? "",
           selectedGameVersion: selectedGameVersion,
           selectedModLoader: indexInfo.loaderType,
           pendingIconData: nil,
           playerListViewModel: nil,
           gameRepository: gameRepository,
           onSuccess: {
               Task { @MainActor in
                   await installModPackDependencies(
                       gameName: gameName,
                       indexInfo: indexInfo,
                       extractedPath: extractedPath
                   )
               }
           },
           onError: { error, message in
               Task { @MainActor in
                   Logger.shared.error("游戏设置失败: \(message)")
                   GlobalErrorHandler.shared.handle(error)
               }
           }
       )
   }
   
   private func installModPackDependencies(
       gameName: String,
       indexInfo: ModrinthIndexInfo,
       extractedPath: URL
   ) async {
       guard let savedGame = gameRepository.getGameByName(by: gameName) else {
           handleGameNotFound(gameName: gameName)
           return
       }
       
       // 计算需要处理的文件数量
       let filesToDownload = indexInfo.files.filter { file in
           if let env = file.env, let client = env.client, client.lowercased() == "unsupported" {
               return false
           }
           return true
       }
       let requiredDependencies = indexInfo.dependencies.filter { $0.dependencyType == "required" }
       
       // 开始安装进度
       viewModel.modPackInstallState.startInstallation(
           filesTotal: filesToDownload.count,
           dependenciesTotal: requiredDependencies.count
       )
       
       let success = await ModPackDependencyInstaller.installVersionDependencies(
           indexInfo: indexInfo,
           gameInfo: savedGame,
           extractedPath: extractedPath,
           onProgressUpdate: { fileName, completed, total, type in
               Task { @MainActor in
                   viewModel.objectWillChange.send()
                   updateInstallProgress(fileName: fileName, completed: completed, total: total, type: type)
               }
           }
       )
       
       handleInstallationResult(success: success, gameName: gameName)
   }
   
   private func updateInstallProgress(fileName: String, completed: Int, total: Int, type: ModPackDependencyInstaller.DownloadType) {
       switch type {
       case .files:
           viewModel.modPackInstallState.updateFilesProgress(
               fileName: fileName,
               completed: completed,
               total: total
           )
       case .dependencies:
           viewModel.modPackInstallState.updateDependenciesProgress(
               dependencyName: fileName,
               completed: completed,
               total: total
           )
       case .overrides:
           viewModel.modPackInstallState.updateOverridesProgress(
               overrideName: fileName,
               completed: completed,
               total: total
           )
       }
   }
   
   private func handleGameNotFound(gameName: String) {
       Logger.shared.error("无法从 gameRepository 获取游戏信息: \(gameName)")
       let globalError = GlobalError.configuration(
           chineseMessage: "无法获取游戏信息，整合包依赖安装失败",
           i18nKey: "error.configuration.game_info_not_found",
           level: .notification
       )
       GlobalErrorHandler.shared.handle(globalError)
   }
   
   private func handleInstallationResult(success: Bool, gameName: String) {
       if success {
           Logger.shared.info("整合包依赖安装完成: \(gameName)")
       } else {
           Logger.shared.error("整合包依赖安装失败: \(gameName)")
           let globalError = GlobalError.resource(
               chineseMessage: "整合包依赖安装失败",
               i18nKey: "error.resource.modpack_dependencies_failed",
               level: .notification
           )
           GlobalErrorHandler.shared.handle(globalError)
       }
       
       viewModel.modPackInstallState.reset()
       dismiss()
   }
}

// MARK: - Preview

#Preview {
   ModPackDownloadSheet(
       projectId: "1KVo5zza",
       gameInfo: nil,
       query: "modpack"
   )
   .environmentObject(GameRepository())
   .frame(height: 600)
}
