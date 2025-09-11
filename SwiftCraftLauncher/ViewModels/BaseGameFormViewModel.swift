//
//  BaseGameFormViewModel.swift
//  SwiftCraftLauncher
//
//  Created by AI Assistant on 2025/1/27.
//

import SwiftUI
import Combine

// MARK: - Base Game Form View Model
@MainActor
class BaseGameFormViewModel: ObservableObject, GameFormStateProtocol {
    @Published var isDownloading: Bool = false
    @Published var isFormValid: Bool = false
    @Published var triggerConfirm: Bool = false
    @Published var triggerCancel: Bool = false

    let gameSetupService = GameSetupUtil()
    let gameNameValidator: GameNameValidator

    internal var downloadTask: Task<Void, Error>?
    private var cancellables = Set<AnyCancellable>()
    let configuration: GameFormConfiguration

    init(configuration: GameFormConfiguration) {
        self.configuration = configuration
        self.gameNameValidator = GameNameValidator(gameSetupService: gameSetupService)

        // 监听子对象的状态变化
        setupObservers()

        // 设置初始状态
        updateParentState()
    }

    private func setupObservers() {
        // 监听gameNameValidator的变化
        gameNameValidator.objectWillChange
            .sink { [weak self] in
                DispatchQueue.main.async {
                    self?.updateParentState()
                    self?.objectWillChange.send()
                }
            }
            .store(in: &cancellables)
        // 监听gameSetupService的变化
        gameSetupService.objectWillChange
            .sink { [weak self] in
                DispatchQueue.main.async {
                    self?.updateParentState()
                    self?.objectWillChange.send()
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - GameFormStateProtocol Implementation
    func handleCancel() {
        if isDownloading {
            // 停止下载任务
            downloadTask?.cancel()
            downloadTask = nil

            // 取消下载状态
            gameSetupService.downloadState.cancel()

            // 执行取消后的清理工作
            Task {
                await performCancelCleanup()
            }
        } else {
            configuration.actions.onCancel()
        }
    }

    func handleConfirm() {
        downloadTask?.cancel()
        downloadTask = Task {
            await performConfirmAction()
        }
    }

    func updateParentState() {
        let newIsDownloading = computeIsDownloading()
        let newIsFormValid = computeIsFormValid()

        // 使用 DispatchQueue.main.async 避免在视图更新期间修改状态
        DispatchQueue.main.async { [weak self] in
            self?.configuration.isDownloading.wrappedValue = newIsDownloading
            self?.configuration.isFormValid.wrappedValue = newIsFormValid

            // 同步本地状态
            self?.isDownloading = newIsDownloading
            self?.isFormValid = newIsFormValid
        }
    }

    // MARK: - Virtual Methods (to be overridden)

    func performConfirmAction() async {
        // Override in subclasses
        configuration.actions.onConfirm()
    }

    func performCancelCleanup() async {
        // Override in subclasses for custom cleanup logic
        // 默认实现：重置下载状态并关闭窗口
        await MainActor.run {
            gameSetupService.downloadState.reset()
            configuration.actions.onCancel()
        }
    }

    func computeIsDownloading() -> Bool {
        return gameSetupService.downloadState.isDownloading
    }

    func computeIsFormValid() -> Bool {
        return gameNameValidator.isFormValid
    }

    // MARK: - Common Download Management
    func startDownloadTask(_ task: @escaping () async -> Void) {
        downloadTask?.cancel()
        downloadTask = Task {
            await task()
        }
    }

    func cancelDownloadIfNeeded() {
        if isDownloading {
            downloadTask?.cancel()
            downloadTask = nil
        } else {
            configuration.actions.onCancel()
        }
    }

    // MARK: - Setup Methods
    func handleNonCriticalError(_ error: GlobalError, message: String) {
        Logger.shared.error("\(message): \(error.chineseMessage)")
        GlobalErrorHandler.shared.handle(error)
    }
}
