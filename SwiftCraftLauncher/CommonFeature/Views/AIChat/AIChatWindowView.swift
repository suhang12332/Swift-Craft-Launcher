//
//  AIChatWindowView.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import SwiftUI
import UniformTypeIdentifiers

/// Provides the main AI chat window interface.
struct AIChatWindowView: View {
    @Environment(DIContainer.self)
    private var container

    var chatState: ChatState
    @Environment(PlayerListViewModel.self)
    private var playerListViewModel
    @Environment(GameRepository.self)
    private var gameRepository
    @State private var attachmentManager = AIChatAttachmentManager()
    @State private var viewModel = AIChatWindowViewModel()
    @State private var inputText = ""
    @State private var showFilePicker = false

    init(
        chatState: ChatState,
    ) {
        self.chatState = chatState
    }

    var body: some View {
        VStack(spacing: 0) {
            AIChatMessageListView(
                chatState: chatState,
                currentPlayer: playerListViewModel.currentPlayer,
                cachedAIAvatar: viewModel.cachedAIAvatar,
                cachedUserAvatar: viewModel.cachedUserAvatar,
                aiAvatarURL: container.ui.aiSettingsManager.aiAvatarURL,
            )

            Divider()

            if !attachmentManager.pendingAttachments.isEmpty {
                AIChatAttachmentPreviewView(
                    attachments: attachmentManager.pendingAttachments,
                ) { index in
                    attachmentManager.removeAttachment(at: index)
                }
            }

            AIChatInputAreaView(
                inputText: $inputText,
                selectedGameId: $viewModel.selectedGameId,
                games: gameRepository.games,
                isSending: chatState.isSending,
                canSend: canSend,
                onSend: sendMessage,
            ) {
                showFilePicker = true
            }
        }
        .frame(minWidth: AuxiliaryWindowID.aiChat.defaultSize.width, minHeight: AuxiliaryWindowID.aiChat.defaultSize.height)
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.text, .pdf, .json, .plainText, .log],
            allowsMultipleSelection: true,
        ) { result in
            handleFileSelection(result)
        }
        .fileDialogDefaultDirectory(
            selectedGame.map { AppPaths.profileDirectory(gameName: $0.gameName) } ?? FileManager.default.homeDirectoryForCurrentUser,
        )
        .onAppear {
            viewModel.onAppear(
                games: gameRepository.games,
                currentPlayer: playerListViewModel.currentPlayer,
                aiAvatarURL: container.ui.aiSettingsManager.aiAvatarURL,
            )
        }
        .onChange(of: gameRepository.games) { _, newGames in
            viewModel.onGamesChanged(newGames)
        }
        .onChange(of: playerListViewModel.currentPlayer?.id) { _, _ in
            viewModel.onPlayerChanged(playerListViewModel.currentPlayer)
        }
        .onChange(of: container.ui.aiSettingsManager.aiAvatarURL) { oldValue, newValue in
            if oldValue != newValue {
                viewModel.onAIAvatarURLChanged(newValue)
            }
        }
        .onDisappear {
            clearAllData()
        }
    }

    private var selectedGame: GameVersionInfo? {
        guard let selectedGameId = viewModel.selectedGameId else { return nil }
        return gameRepository.games.first { $0.id == selectedGameId }
    }

    private var canSend: Bool {
        !chatState.isSending && (!inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !attachmentManager.pendingAttachments.isEmpty)
    }

    private func clearAllData() {
        viewModel.clearAllData()
        inputText = ""
        attachmentManager.clearAll()
    }

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard canSend else { return }

        let attachments = attachmentManager.pendingAttachments
        inputText = ""
        attachmentManager.clearAll()

        Task {
            await container.ui.aiChatManager.sendMessage(text, attachments: attachments, chatState: chatState)
        }
    }

    private func handleFileSelection(_ result: Result<[URL], Error>) {
        switch result {
        case let .success(urls):
            attachmentManager.handleFileSelection(urls)
        case let .failure(error):
            let globalError = GlobalError.from(error)
            container.core.errorHandler.handle(globalError)
        }
    }
}
