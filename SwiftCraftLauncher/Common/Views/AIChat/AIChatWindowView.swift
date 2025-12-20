//
//  AIChatWindow.swift
//  SwiftCraftLauncher
//
//

import SwiftUI

/// AI 对话窗口视图
struct AIChatWindowView: View {
    @ObservedObject var chatState: ChatState
    @StateObject private var playerListViewModel = PlayerListViewModel()
    @StateObject private var gameRepository = GameRepository()
    @StateObject private var aiSettings = AISettingsManager.shared
    @StateObject private var attachmentManager = AIChatAttachmentManager()
    @State private var inputText = ""
    @FocusState private var isInputFocused: Bool
    @State private var selectedGameId: String?

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
                attachmentManager.openFilePicker(selectedGame: selectedGame)
            }
        }
        .frame(minWidth: 500, minHeight: 600)
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
}

// MARK: - Helper Views

struct AIAvatarView: View {
    let size: CGFloat
    let url: String

    init(size: CGFloat, url: String = "https://mcskins.top/assets/snippets/download/skin.php?n=7050") {
        self.size = size
        self.url = url
    }

    var body: some View {
        MinecraftSkinUtils(
            type: .url,
            src: url,
            size: size
        )
    }
}

/// 消息气泡视图
struct MessageBubble: View {
    let message: ChatMessage
    let currentPlayer: Player?
    let cachedAIAvatar: AnyView?
    let cachedUserAvatar: AnyView?
    let aiAvatarURL: String

    private enum Constants {
        static let avatarSize: CGFloat = 32
        static let messageFontSize: CGFloat = 13
        static let timestampFontSize: CGFloat = 10
        static let messageCornerRadius: CGFloat = 10
        static let messageMaxWidth: CGFloat = 500
        static let messageSpacing: CGFloat = 16
        static let messageVerticalPadding: CGFloat = 2
        static let contentHorizontalPadding: CGFloat = 12
        static let contentVerticalPadding: CGFloat = 8
        static let timestampHorizontalPadding: CGFloat = 4
        static let timestampTopPadding: CGFloat = 2
        static let attachmentSpacing: CGFloat = 6
        static let attachmentBottomPadding: CGFloat = 4
        static let spacerMinLength: CGFloat = 40
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Constants.messageSpacing) {
            if message.role == .user {
                userMessageView
            } else {
                aiMessageView
            }
        }
        .padding(.vertical, Constants.messageVerticalPadding)
    }

    // MARK: - User Message View

    @ViewBuilder private var userMessageView: some View {
        Spacer(minLength: Constants.spacerMinLength)
        messageContentView(alignment: .trailing, isUser: true)
        userAvatarView
    }

    // MARK: - AI Message View

    @ViewBuilder private var aiMessageView: some View {
        // 使用缓存的 AI 头像，避免每次重新加载
        if let cachedAvatar = cachedAIAvatar {
            cachedAvatar
        } else {
            AIAvatarView(size: Constants.avatarSize, url: aiAvatarURL)
        }
        messageContentView(alignment: .leading, isUser: false)
        Spacer(minLength: Constants.spacerMinLength)
    }

    // MARK: - Message Content

    private func messageContentView(alignment: HorizontalAlignment, isUser: Bool) -> some View {
        VStack(alignment: alignment, spacing: 4) {
            if !message.attachments.isEmpty {
                attachmentsView(alignment: alignment)
                    .padding(.bottom, message.content.isEmpty ? 0 : Constants.attachmentBottomPadding)
            }

            if !message.content.isEmpty {
                messageTextBubble
            }

            timestampView
        }
        .frame(maxWidth: Constants.messageMaxWidth, alignment: alignment == .leading ? .leading : .trailing)
    }

    private func attachmentsView(alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: Constants.attachmentSpacing) {
            ForEach(Array(message.attachments.enumerated()), id: \.offset) { _, attachment in
                AttachmentView(attachment: attachment)
            }
        }
    }

    @ViewBuilder private var messageTextBubble: some View {
        Text(message.content)
            .textSelection(.enabled)
            .font(.system(size: Constants.messageFontSize))
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)
    }

    private var timestampView: some View {
        Text(message.timestamp, style: .time)
            .font(.system(size: Constants.timestampFontSize))
            .foregroundStyle(.tertiary)
            .padding(.horizontal, Constants.timestampHorizontalPadding)
            .padding(.top, Constants.timestampTopPadding)
    }

    // MARK: - Avatar Views

    @ViewBuilder private var userAvatarView: some View {
        // 使用缓存的用户头像，避免每次重新加载
        if let cachedAvatar = cachedUserAvatar {
            cachedAvatar
        } else if let player = currentPlayer {
            MinecraftSkinUtils(
                type: player.isOnlineAccount ? .url : .asset,
                src: player.avatarName,
                size: Constants.avatarSize
            )
        } else {
            Image(systemName: "person.fill")
                .font(.system(size: Constants.avatarSize))
                .foregroundStyle(.secondary)
        }
    }
}

/// 附件预览视图（输入区域）
struct AttachmentPreview: View {
    let attachment: MessageAttachmentType
    let onRemove: () -> Void

    private enum Constants {
        static let previewSize: CGFloat = 18
        static let cornerRadius: CGFloat = 6
        static let containerCornerRadius: CGFloat = 8
        static let padding: CGFloat = 4
        static let spacing: CGFloat = 6
    }

    var body: some View {
        HStack(spacing: Constants.spacing) {
            switch attachment {
            case .image:
                // 图片类型已移除，不应该出现
                EmptyView()
            case let .file(_, fileName):
                Image(systemName: "doc.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.blue)
                    .frame(width: Constants.previewSize, height: Constants.previewSize)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: Constants.cornerRadius))

                Text(fileName)
                    .font(.caption)
                    .lineLimit(1)
                    .frame(maxWidth: 100)
            }

            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(Constants.padding)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: Constants.containerCornerRadius))
    }
}

/// 附件显示视图（消息中）
struct AttachmentView: View {
    let attachment: MessageAttachmentType

    private enum Constants {
        static let imageMaxSize: CGFloat = 300
        static let imageCornerRadius: CGFloat = 12
        static let fileIconSize: CGFloat = 32
        static let fileSpacing: CGFloat = 8
        static let filePadding: CGFloat = 10
        static let fileCornerRadius: CGFloat = 8
        static let fileMaxWidth: CGFloat = 180
        static let fileNameMaxWidth: CGFloat = 120
    }

    var body: some View {
        switch attachment {
        case .image:
            // 图片类型已移除，不应该出现
            EmptyView()
        case let .file(url, fileName):
            fileItemView(
                iconName: "doc.fill",
                fileName: fileName,
                fileExtension: url.pathExtension.uppercased(),
                url: url
            )
        }
    }

    @ViewBuilder
    private func fileItemView(
        iconName: String,
        fileName: String,
        fileExtension: String,
        url: URL
    ) -> some View {
        HStack(spacing: Constants.fileSpacing) {
            Image(systemName: iconName)
                .font(.system(size: 18))
                .foregroundStyle(.blue)
                .frame(width: Constants.fileIconSize, height: Constants.fileIconSize)

            VStack(alignment: .leading, spacing: 2) {
                Text(fileName)
                    .font(.system(size: 12))
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(fileExtension)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: Constants.fileNameMaxWidth, alignment: .leading)
        }
        .padding(Constants.filePadding)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: Constants.fileCornerRadius))
        .frame(maxWidth: Constants.fileMaxWidth)
        .contentShape(Rectangle())
        .onTapGesture {
            NSWorkspace.shared.activateFileViewerSelecting([url])
        }
    }
}

#Preview {
    let chatState = ChatState()

//    // 添加示例消息
//    chatState.addMessage(ChatMessage(
//        role: .user,
//        content: "你好，请帮我分析一下这个游戏启动失败的问题。"
//    ))
//    chatState.addMessage(ChatMessage(
//        role: .assistant,
//        content: "你好！我很乐意帮助你分析游戏启动失败的问题。请提供相关的错误日志或详细信息，我会仔细分析并给出解决方案。"
//    ))

    return AIChatWindowView(chatState: chatState)
        .frame(width: 400, height: 300)
}
