//
//  OfflineAuthView.swift
//  PlayerFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import SwiftUI

/// Displays the offline account creation flow, allowing the user to input a custom player name.
struct OfflineAuthView: View {
    @Environment(PlayerListViewModel.self)
    private var playerListViewModel

    @Binding var playerName: String
    @Binding var isPlayerNameValid: Bool

    @State private var showErrorPopover: Bool = false

    var body: some View {
        VStack(alignment: .leading) {
            playerInfoSection
                .padding(.bottom, 10)
            playerNameInputSection
        }
    }

    private var playerInfoSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("addplayer.info.title".localized())
                .font(.headline)
                .padding(.bottom, 4)

            Text("addplayer.info.line1".localized())
                .font(.subheadline)
                .foregroundColor(.secondary)
            Text("addplayer.info.line2".localized())
                .font(.subheadline)
                .foregroundColor(.secondary)
            Text("addplayer.info.line3".localized())
                .font(.subheadline)
                .foregroundColor(.secondary)
            Text("addplayer.info.line4".localized())
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }

    private var playerNameInputSection: some View {
        VStack(alignment: .leading) {
            Text("addplayer.name.label".localized())
                .font(.headline)
            TextField(
                "addplayer.name.placeholder".localized(),
                text: $playerName,
            )
            .textFieldStyle(.roundedBorder)
            .popover(isPresented: $showErrorPopover, arrowEdge: .trailing) {
                if let errorMessage = playerNameError {
                    Text(errorMessage)
                        .padding()
                        .presentationCompactAdaptation(.popover)
                }
            }
            .onChange(of: playerName) { _, newValue in
                checkPlayerName(newValue)
            }
        }
    }

    private var playerNameError: String? {
        errorMessage(for: playerName)
    }

    private func errorMessage(for name: String) -> String? {
        guard !name.isEmpty else { return nil }
        if !PlayerUtils.isValidOfflineNameCharacters(name) {
            return "addplayer.name.error.invalid_characters".localized()
        }
        if !PlayerUtils.isValidOfflineNameLength(name) {
            return "addplayer.name.error.invalid_length".localized()
        }
        if playerListViewModel.playerExists(name: name) {
            return "addplayer.name.error.duplicate".localized()
        }
        return nil
    }

    private func checkPlayerName(_ name: String) {
        let hasError = errorMessage(for: name) != nil
        isPlayerNameValid = PlayerUtils.isValidOfflineName(name) && !hasError
        showErrorPopover = hasError
    }
}
