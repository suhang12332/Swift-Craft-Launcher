//
//  ModPackUpdateViewModel.swift
//  ModPackFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation
import SwiftUI
import ZIPFoundation

/// Updates a linked Modrinth pack within the current Minecraft version and loader.
@MainActor
@Observable
final class ModPackUpdateViewModel {
    private(set) var game: GameVersionInfo
    let profile: URL
    let workingPath: String
    var installedPack: InstalledModPack?
    var projectId = ""
    var versions: [ModrinthProjectDetailVersion] = []
    var selectedVersionId = ""
    var isBusy = false
    var errorMessage: String?
    var backup: URL?
    let gameSetupService = GameSetupUtil()

    init(game: GameVersionInfo) {
        self.game = game
        workingPath = DIContainer.shared.ui.generalSettingsManager.currentWorkingPath
        profile = AppPaths.profileDirectory(gameName: game.gameName)
        do {
            if FileManager.default.fileExists(atPath: profile.appendingPathComponent(InstalledModPack.fileName).path) {
                installedPack = try InstalledModPack.load(from: profile)
                projectId = installedPack?.projectId ?? ""
            }
        } catch { errorMessage = error.localizedDescription }
    }

    static func eligibleVersions(
        _ versions: [ModrinthProjectDetailVersion],
        game: GameVersionInfo,
        installed: InstalledModPack?,
    ) -> [ModrinthProjectDetailVersion] {
        versions
            .filter { version in
                guard version.gameVersions.contains(game.gameVersion),
                      version.loaders.contains(game.modLoader.lowercased()),
                      version.files.contains(where: { $0.filename.hasSuffix(".mrpack") })
                else { return false }
                guard let installed else { return true }
                return version.projectId == installed.projectId
                    && version.id != installed.versionId
                    && version.datePublished > installed.publishedAt
                    && (installed.versionType != "release" || version.versionType == "release")
            }
            .sorted { $0.datePublished > $1.datePublished }
    }

    func loadVersions() async {
        guard !isBusy, !projectId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        isBusy = true
        errorMessage = nil
        versions = []
        selectedVersionId = ""
        defer { isBusy = false }
        do {
            let detail = try await ModrinthService.fetchProjectDetailsThrowing(id: projectId.trimmingCharacters(in: .whitespacesAndNewlines))
            guard detail.projectType == "modpack", !detail.id.asProjectId.isCurseForge else {
                throw ModPackUpdateError.incompatible
            }
            projectId = detail.id
            let available = try await ModrinthService.fetchProjectVersionsThrowing(id: detail.id)
            versions = Self.eligibleVersions(available, game: game, installed: installedPack)
            selectedVersionId = versions.first?.id ?? ""
        } catch { errorMessage = error.localizedDescription }
    }

    /// Links an exact installed release or stages and commits a newer release.
    func confirm(repository: GameRepository) async {
        guard !isBusy, let version = versions.first(where: { $0.id == selectedVersionId }) else { return }
        isBusy = true
        errorMessage = nil
        let status = DIContainer.shared.core.gameStatusManager
        var hasLock = false
        let workspace = profile
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent(".modpack-updates/\(UUID().uuidString)")
        defer {
            if hasLock {
                status.endModPackUpdate(gameId: game.id)
            }
            try? FileManager.default.removeItem(at: workspace)
            gameSetupService.downloadState.reset()
            isBusy = false
        }
        do {
            try status.beginModPackUpdate(gameId: game.id, profile: profile)
            hasLock = true
            guard AppPaths.profileDirectory(gameName: game.gameName) == profile,
                  repository.getGame(by: game.id) == game
            else { throw ModPackUpdateError.busy }
            try FileManager.default.createDirectory(at: workspace, withIntermediateDirectories: true)
            let (extracted, index) = try await downloadPack(version, workspace: workspace)
            guard index.gameVersion == game.gameVersion, index.loaderType == game.modLoader else {
                throw ModPackUpdateError.incompatible
            }
            let manifest = try ModPackUpdateFiles.manifest(index: index, extracted: extracted, version: version)
            if let installedPack {
                try await update(
                    old: installedPack,
                    new: manifest,
                    index: index,
                    extracted: extracted,
                    workspace: workspace,
                    repository: repository,
                )
            } else {
                try ModPackUpdateFiles.validateLink(manifest, profile: profile)
                try manifest.save(to: profile)
            }
            installedPack = try InstalledModPack.load(from: profile)
            versions = []
            selectedVersionId = ""
        } catch { errorMessage = error.localizedDescription }
    }

    private func downloadPack(
        _ version: ModrinthProjectDetailVersion,
        workspace: URL,
    ) async throws -> (URL, ModrinthIndexInfo) {
        guard let file = version.files.first(where: { $0.primary && $0.filename.hasSuffix(".mrpack") })
            ?? version.files.first(where: { $0.filename.hasSuffix(".mrpack") })
        else { throw ModPackUpdateError.incomplete }
        let archiveURL = workspace.appendingPathComponent("pack.mrpack")
        _ = try await DownloadManager.downloadFile(urlString: file.url, destinationURL: archiveURL, expectedSha1: file.hashes.sha1)
        try Task.checkCancellation()
        let extracted = workspace.appendingPathComponent("extracted")
        let archive = try Archive(url: archiveURL, accessMode: .read)
        for entry in archive {
            guard entry.type != .symlink else { throw ModPackUpdateError.unsafePath(entry.path) }
            let path = entry.path.hasSuffix("/") ? String(entry.path.dropLast()) : entry.path
            _ = try InstalledModPack.fileURL(path, in: extracted)
        }
        try FileManager.default.unzipItem(at: archiveURL, to: extracted)
        let raw = try JSONDecoder().decode(
            ModrinthIndex.self,
            from: Data(contentsOf: extracted.appendingPathComponent(AppConstants.modrinthIndexFileName)),
        )
        guard raw.formatVersion == 1, raw.game == "minecraft",
              let index = await ModrinthIndexAdapter().parseToModrinthIndexInfo(extractedPath: extracted)
        else { throw ModPackUpdateError.incompatible }
        return (extracted, index)
    }

    private func update(
        old: InstalledModPack,
        new: InstalledModPack,
        index: ModrinthIndexInfo,
        extracted: URL,
        workspace: URL,
        repository: GameRepository,
    ) async throws {
        guard new.projectId == old.projectId, new.publishedAt > old.publishedAt else {
            throw ModPackUpdateError.incompatible
        }
        try ModPackUpdateFiles.validateLink(old, profile: profile)
        let payload = workspace.appendingPathComponent("payload")
        try FileManager.default.createDirectory(at: payload, withIntermediateDirectories: true)
        for file in index.files where file.env?.client != "unsupported" {
            try Task.checkCancellation()
            let destination = try InstalledModPack.fileURL(file.path, in: payload)
            guard let url = file.downloads.first, let hash = file.hashes.sha1 else { throw ModPackUpdateError.incomplete }
            _ = try await DownloadManager.downloadFile(urlString: url, destinationURL: destination, expectedSha1: hash)
        }
        for folder in ["overrides", "client-overrides"] {
            let root = extracted.appendingPathComponent(folder)
            if FileManager.default.fileExists(atPath: root.path) {
                for path in try ModPackUpdateFiles.relativeFiles(in: root) {
                    let destination = try InstalledModPack.fileURL(path, in: payload)
                    try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
                    if FileManager.default.fileExists(atPath: destination.path) {
                        try FileManager.default.removeItem(at: destination)
                    }
                    try FileManager.default.copyItem(at: InstalledModPack.fileURL(path, in: root), to: destination)
                }
            }
        }
        var updatedGame = game
        if index.loaderVersion != game.modVersion {
            updatedGame = try await gameSetupService.prepareGameLoaderUpdate(
                input: .init(selectedModLoader: game.modLoader, specifiedLoaderVersion: index.loaderVersion),
                existingGame: game,
            )
        }
        let fingerprint = try ModPackUpdateFiles.profileFingerprint(profile)
        let replacement = workspace.appendingPathComponent("replacement")
        try await Task.detached(priority: .userInitiated) { [profile] in
            try FileManager.default.copyItem(at: profile, to: replacement)
            try ModPackUpdateFiles.merge(old: old, new: new, payload: payload, replacement: replacement)
        }.value
        try Task.checkCancellation()
        guard AppPaths.profileDirectory(gameName: game.gameName) == profile,
              repository.getGame(by: game.id) == game,
              try InstalledModPack.load(from: profile).versionId == old.versionId
        else { throw ModPackUpdateError.busy }
        let backupURL = profile
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("modpack-backups/\(game.gameName)-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: backupURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try await Task.detached(priority: .userInitiated) { [profile] in
            try FileManager.default.copyItem(at: profile, to: backupURL)
        }.value
        backup = backupURL
        try Task.checkCancellation()
        guard AppPaths.profileDirectory(gameName: game.gameName) == profile,
              repository.getGame(by: game.id) == game,
              try ModPackUpdateFiles.profileFingerprint(profile) == fingerprint
        else { throw ModPackUpdateError.busy }
        _ = try FileManager.default.replaceItemAt(profile, withItemAt: replacement)
        do {
            try await repository.updateGame(updatedGame, duringModPackUpdate: true, workingPath: workingPath)
        } catch {
            // Keep the backup even if restoring fails. Never delete the user's rollback copy.
            let restore = workspace.appendingPathComponent("restore")
            try FileManager.default.copyItem(at: backupURL, to: restore)
            _ = try FileManager.default.replaceItemAt(profile, withItemAt: restore)
            throw error
        }
        NotificationCenter.default.post(name: .localResourceImported, object: nil)
        game = updatedGame
    }
}
