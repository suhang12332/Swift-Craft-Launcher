//
//  AIChatWindow.swift
//  SwiftCraftLauncher
//
//

import SwiftUI
import UniformTypeIdentifiers

/// AI 对话窗口视图
struct AIChatWindowView: View {
    @ObservedObject var chatState: ChatState
    @EnvironmentObject var playerListViewModel: PlayerListViewModel
    @EnvironmentObject var gameRepository: GameRepository
    @StateObject private var aiSettings = AISettingsManager.shared
    @StateObject private var attachmentManager = AIChatAttachmentManager()
    @StateObject private var viewModel = AIChatWindowViewModel()
    @State private var inputText = ""
    @FocusState private var isInputFocused: Bool
    @State private var showFilePicker = false

    var body: some View {
        VStack(spacing: 0) {
            // 消息列表
            AIChatMessageListView(
                chatState: chatState,
                currentPlayer: playerListViewModel.currentPlayer,
                cachedAIAvatar: viewModel.cachedAIAvatar,
                cachedUserAvatar: viewModel.cachedUserAvatar,
                aiAvatarURL: aiSettings.aiAvatarURL
            )

            Divider()

            // 待发送附件预览
            if !attachmentManager.pendingAttachments.isEmpty {
                AIChatAttachmentPreviewView(
                    attachments: attachmentManager.pendingAttachments
                ) { index in
                    attachmentManager.removeAttachment(at: index)
                }
            }

            // 输入区域
            AIChatInputAreaView(
                inputText: $inputText,
                selectedGameId: $viewModel.selectedGameId,
                isInputFocused: $isInputFocused,
                games: gameRepository.games,
                isSending: chatState.isSending,
                canSend: canSend,
                onSend: sendMessage
            ) {
                showFilePicker = true
            }
        }
        .frame(minWidth: 500, minHeight: 600)
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.text, .pdf, .json, .plainText, .log],
            allowsMultipleSelection: true
        ) { result in
            handleFileSelection(result)
        }
        .fileDialogDefaultDirectory(
            selectedGame.map { AppPaths.profileDirectory(gameName: $0.gameName) } ?? FileManager.default.homeDirectoryForCurrentUser
        )
        .onAppear {
            isInputFocused = true
            viewModel.onAppear(
                games: gameRepository.games,
                currentPlayer: playerListViewModel.currentPlayer,
                aiAvatarURL: aiSettings.aiAvatarURL
            )
        }
        .onChange(of: gameRepository.games) { _, newGames in
            // 当游戏列表加载完成且未选择游戏时，自动选择第一个游戏
            viewModel.onGamesChanged(newGames)
        }
        .onChange(of: playerListViewModel.currentPlayer?.id) { _, _ in
            // 当当前玩家变化时，更新用户头像缓存（仅监听 ID 变化，减少不必要的更新）
            viewModel.onPlayerChanged(playerListViewModel.currentPlayer)
        }
        .onChange(of: aiSettings.aiAvatarURL) { oldValue, newValue in
            // 当 AI 头像 URL 变化时，更新 AI 头像缓存（仅在 URL 实际变化时更新）
            if oldValue != newValue {
                viewModel.onAIAvatarURLChanged(newValue)
            }
        }
        .onDisappear {
            // 页面关闭后清除所有数据
            clearAllData()
        }
    }

    // MARK: - Computed Properties

    private var selectedGame: GameVersionInfo? {
        guard let selectedGameId = viewModel.selectedGameId else { return nil }
        return gameRepository.games.first { $0.id == selectedGameId }
    }

    private var canSend: Bool {
        !chatState.isSending && (!inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !attachmentManager.pendingAttachments.isEmpty)
    }

    // MARK: - Methods

    /// 清除页面所有数据
    private func clearAllData() {
        viewModel.clearAllData()
        // 清理输入文本和附件
        inputText = ""
        attachmentManager.clearAll()
        // 重置焦点状态
        isInputFocused = false
    }

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard canSend else { return }

        let attachments = attachmentManager.pendingAttachments
        inputText = ""
        attachmentManager.clearAll()

        Task {
            await AIChatManager.shared.sendMessage(text, attachments: attachments, chatState: chatState)
        }
    }

    /// 处理文件选择结果
    private func handleFileSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            attachmentManager.handleFileSelection(urls)
        case .failure(let error):
            let globalError = GlobalError.from(error)
            GlobalErrorHandler.shared.handle(globalError)
        }
    }
}
