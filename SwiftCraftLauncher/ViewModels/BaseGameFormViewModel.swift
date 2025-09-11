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
    
    let gameSetupService = GameSetupUtil()
    let gameNameValidator: GameNameValidator
    
    private var downloadTask: Task<Void, Error>?
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
        gameNameValidator.objectWillChange.sink { [weak self] in
            DispatchQueue.main.async {
                self?.updateParentState()
                self?.objectWillChange.send()
            }
        }.store(in: &cancellables)
        
        // 监听gameSetupService的变化
        gameSetupService.objectWillChange.sink { [weak self] in
            DispatchQueue.main.async {
                self?.updateParentState()
                self?.objectWillChange.send()
            }
        }.store(in: &cancellables)
    }
    
    // MARK: - GameFormStateProtocol Implementation
    
    func handleCancel() {
        if isDownloading {
            downloadTask?.cancel()
            downloadTask = nil
        }
        configuration.actions.onCancel()
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
