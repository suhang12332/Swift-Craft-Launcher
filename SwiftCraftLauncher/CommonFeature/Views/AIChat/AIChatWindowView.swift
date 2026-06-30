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
    @ObservedObject var chatState: ChatState
    @EnvironmentObject private var playerListViewModel: PlayerListViewModel
    @EnvironmentObject private var gameRepository: GameRepository
    @StateObject private var aiSettings: AISettingsManager
    private let aiChatManager: AIChatManager
    private let errorHandler: GlobalErrorHandler
    @StateObject private var attachmentManager = AIChatAttachmentManager()
    @StateObject private var viewModel = AIChatWindowViewModel()
    @State private var inputText = ""
    @FocusState private var isInputFocused: Bool
    @State private var showFilePicker = false

    init(
        chatState: ChatState,
        aiSettings: AISettingsManager = AppServices.aiSettingsManager,
        aiChatManager: AIChatManager = AppServices.aiChatManager,
        errorHandler: GlobalErrorHandler = AppServices.errorHandler,
    ) {
        self.chatState = chatState
        _aiSettings = StateObject(wrappedValue: aiSettings)
        self.aiChatManager = aiChatManager
        self.errorHandler = errorHandler
    }

    var body: some View {
        VStack(spacing: 0) {
            AIChatMessageListView(
                chatState: chatState,
                currentPlayer: playerListViewModel.currentPlayer,
                cachedAIAvatar: viewModel.cachedAIAvatar,
                cachedUserAvatar: viewModel.cachedUserAvatar,
                aiAvatarURL: aiSettings.aiAvatarURL,
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
                isInputFocused: $isInputFocused,
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
            isInputFocused = true
            viewModel.onAppear(
                games: gameRepository.games,
                currentPlayer: playerListViewModel.currentPlayer,
                aiAvatarURL: aiSettings.aiAvatarURL,
            )
        }
        .onChange(of: chatState.isSending) { wasSending, isSendingNow in
            if wasSending, !isSendingNow {
                isInputFocused = true
            }
        }
        .onChange(of: gameRepository.games) { _, newGames in
            viewModel.onGamesChanged(newGames)
        }
        .onChange(of: playerListViewModel.currentPlayer?.id) { _, _ in
            viewModel.onPlayerChanged(playerListViewModel.currentPlayer)
        }
        .onChange(of: aiSettings.aiAvatarURL) { oldValue, newValue in
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
        isInputFocused = false
    }

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard canSend else { return }

        let attachments = attachmentManager.pendingAttachments
        inputText = ""
        attachmentManager.clearAll()

        Task {
            await aiChatManager.sendMessage(text, attachments: attachments, chatState: chatState)
        }
    }

    private func handleFileSelection(_ result: Result<[URL], Error>) {
        switch result {
        case let .success(urls):
            attachmentManager.handleFileSelection(urls)
        case let .failure(error):
            let globalError = GlobalError.from(error)
            errorHandler.handle(globalError)
        }
    }
}
