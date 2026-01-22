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
    @State private var inputText = ""
    @FocusState private var isInputFocused: Bool
    @State private var selectedGameId: String?
    @State private var showFilePicker = false

    // 缓存头像视图，避免每次消息更新时重新加载
    @State private var cachedAIAvatar: AnyView?
    @State private var cachedUserAvatar: AnyView?

    // MARK: - Constants
    private enum Constants {
        static let avatarSize: CGFloat = 32
    }

    var body: some View {
        VStack(spacing: 0) {
            // 消息列表
            AIChatMessageListView(
                chatState: chatState,
                currentPlayer: playerListViewModel.currentPlayer,
                cachedAIAvatar: cachedAIAvatar,
                cachedUserAvatar: cachedUserAvatar,
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
                selectedGameId: $selectedGameId,
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
            // 默认选择第一个游戏
            if selectedGameId == nil && !gameRepository.games.isEmpty {
                selectedGameId = gameRepository.games.first?.id
            }
            // 初始化头像缓存
            initializeAvatarCache()
        }
        .onChange(of: gameRepository.games) { _, newGames in
            // 当游戏列表加载完成且未选择游戏时，自动选择第一个游戏
            if selectedGameId == nil && !newGames.isEmpty {
                selectedGameId = newGames.first?.id
            }
        }
        .onChange(of: playerListViewModel.currentPlayer?.id) { _, _ in
            // 当当前玩家变化时，更新用户头像缓存（仅监听 ID 变化，减少不必要的更新）
            updateUserAvatarCache()
        }
        .onChange(of: aiSettings.aiAvatarURL) { oldValue, newValue in
            // 当 AI 头像 URL 变化时，更新 AI 头像缓存（仅在 URL 实际变化时更新）
            if oldValue != newValue {
                updateAIAvatarCache()
            }
        }
        .onDisappear {
            // 页面关闭后清除所有数据
            clearAllData()
        }
    }

    // MARK: - Computed Properties

    private var selectedGame: GameVersionInfo? {
        guard let selectedGameId = selectedGameId else { return nil }
        return gameRepository.games.first { $0.id == selectedGameId }
    }

    private var canSend: Bool {
        !chatState.isSending && (!inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !attachmentManager.pendingAttachments.isEmpty)
    }

    // MARK: - Methods

    /// 初始化头像缓存
    private func initializeAvatarCache() {
        // 初始化 AI 头像（使用设置中的 URL）
        updateAIAvatarCache()

        // 初始化用户头像
        updateUserAvatarCache()
    }

    /// 更新 AI 头像缓存
    private func updateAIAvatarCache() {
        cachedAIAvatar = AnyView(
            AIAvatarView(size: Constants.avatarSize, url: aiSettings.aiAvatarURL)
        )
    }

    /// 更新用户头像缓存
    private func updateUserAvatarCache() {
        if let player = playerListViewModel.currentPlayer {
            cachedUserAvatar = AnyView(
                MinecraftSkinUtils(
                    type: player.isOnlineAccount ? .url : .asset,
                    src: player.avatarName,
                    size: Constants.avatarSize
                )
            )
        } else {
            cachedUserAvatar = AnyView(
                Image(systemName: "person.fill")
                    .font(.system(size: Constants.avatarSize))
                    .foregroundStyle(.secondary)
            )
        }
    }

    /// 清理头像缓存
    private func clearAvatarCache() {
        cachedAIAvatar = nil
        cachedUserAvatar = nil
    }

    /// 清除页面所有数据
    private func clearAllData() {
        // 清理头像缓存
        clearAvatarCache()
        // 清理输入文本和附件
        inputText = ""
        attachmentManager.clearAll()
        // 重置焦点状态
        isInputFocused = false
        // 清理选中的游戏
        selectedGameId = nil
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
