//
//  AddOrDeleteResourceButtonViewModel.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation
import Observation
import os
import SwiftUI

/// View model that manages the add, delete, and update actions for a Modrinth resource button.
@MainActor
@Observable
final class AddOrDeleteResourceButtonViewModel {
    var addButtonState: ModrinthDetailCardView.AddButtonState = .idle
    var isUpdateButtonLoading = false
    var projectPendingDeletion: ModrinthProject?

    var activeAlert: ResourceButtonAlertType?
    var showGlobalResourceSheet = false
    var showModPackDownloadSheet = false
    var showGameResourceInstallSheet = false

    var preloadedDetail: ModrinthProjectDetail?
    var preloadedCompatibleGames: [GameVersionInfo] = []

    var isDisabled = false
    var currentFileName: String?
    var hasDownloadedInSheet = false
    var oldFileNameForUpdate: String?

    let project: ModrinthProject
    let selectedVersions: [String]
    let selectedLoaders: [String]
    let gameInfo: GameVersionInfo?
    let query: String
    let type: Bool

    let onResourceChanged: (() -> Void)?
    let onToggleDisableState: ((Bool) -> Void)?
    let onResourceUpdated: ((String, String, String, String?) -> Void)?
    let setIsResourceDisabled: (Bool) -> Void
    let addScannedHash: (String) -> Void

    var gameRepository: GameRepository?
    var playerListViewModel: PlayerListViewModel?

    init(
        project: ModrinthProject,
        selectedVersions: [String],
        selectedLoaders: [String],
        gameInfo: GameVersionInfo?,
        query: String,
        type: Bool,
        onResourceChanged: (() -> Void)?,
        onResourceUpdated: ((String, String, String, String?) -> Void)?,
        onToggleDisableState: ((Bool) -> Void)?,
        setIsResourceDisabled: @escaping (Bool) -> Void,
        addScannedHash: @escaping (String) -> Void,
    ) {
        self.project = project
        self.selectedVersions = selectedVersions
        self.selectedLoaders = selectedLoaders
        self.gameInfo = gameInfo
        self.query = query
        self.type = type
        self.onResourceChanged = onResourceChanged
        self.onResourceUpdated = onResourceUpdated
        self.onToggleDisableState = onToggleDisableState
        self.setIsResourceDisabled = setIsResourceDisabled
        self.addScannedHash = addScannedHash
    }

    func setDependencies(
        gameRepository: GameRepository,
        playerListViewModel: PlayerListViewModel,
    ) {
        self.gameRepository = gameRepository
        self.playerListViewModel = playerListViewModel
    }

    var effectiveFileName: String? {
        currentFileName ?? project.fileName
    }

    func syncDisableState(using fileName: String?) {
        isDisabled = ResourceEnableDisableManager.isDisabled(fileName: fileName)
        setIsResourceDisabled(isDisabled)
    }
}
