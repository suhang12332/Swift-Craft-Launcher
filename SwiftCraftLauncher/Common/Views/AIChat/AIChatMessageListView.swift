//
//  AIChatMessageListView.swift
//  SwiftCraftLauncher
//
//

import SwiftUI

/// AI 聊天消息列表视图
struct AIChatMessageListView: View {
    @ObservedObject var chatState: ChatState
    let currentPlayer: Player?
    let cachedAIAvatar: AnyView?
    let cachedUserAvatar: AnyView?
    let aiAvatarURL: String

    private enum Constants {
        static let avatarSize: CGFloat = 32
        static let messageSpacing: CGFloat = 16
        static let messageVerticalPadding: CGFloat = 2
        static let scrollDelay: TimeInterval = 0.1
        static let scrollAnimationDuration: TimeInterval = 0.3
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollViewReader { proxy in
                ScrollView {
                    if chatState.messages.isEmpty {
                        // 空消息时显示欢迎语
                        VStack {
                            Spacer()
                            welcomeView
                            Spacer()
                        }
                        .frame(width: geometry.size.width, height: geometry.size.height)
                    } else {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            messageListView

                            // 只有当正在发送且最后一条 AI 消息为空时，才显示"正在思考"
                            if chatState.isSending,
                               let lastMessage = chatState.messages.last,
                               lastMessage.role == .assistant,
                               lastMessage.content.isEmpty {
                                loadingIndicatorView
                            }
                        }
                        .padding()
                    }
                }
                // 滚动到底部：优化 - 合并多个 onChange 以减少不必要的视图更新
                .onChange(of: chatState.messages.count) { _, _ in
                    // 新消息时滚动
                    if chatState.messages.last != nil {
                        scrollToBottom(proxy: proxy)
                    }
                }
                .onChange(of: chatState.messages.last?.content.count ?? 0) { oldValue, newValue in
                    // 流式更新时滚动（仅在内容增加时）
                    if chatState.isSending && newValue > oldValue && newValue > 0 {
                        scrollToBottom(proxy: proxy)
                    }
                }
                .onChange(of: chatState.isSending) { oldValue, newValue in
                    // 发送完成时滚动（仅在状态从 true 变为 false 时）
                    if oldValue && !newValue {
                        scrollToBottom(proxy: proxy)
                    }
                }
            }
        }
    }

    // MARK: - View Components

    private var welcomeView: some View {
        VStack(spacing: 16) {
            if let player = currentPlayer {
                Text(String(format: "ai.chat.welcome.message".localized(), player.name))
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)
            }
            Text("ai.chat.welcome.description".localized())
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
    }

    private var messageListView: some View {
        ForEach(chatState.messages) { message in
            // 跳过正在发送的空 AI 消息（会显示加载指示器）
            if !(chatState.isSending && message.role == .assistant && message.content.isEmpty) {
                MessageBubble(
                    message: message,
                    currentPlayer: currentPlayer,
                    cachedAIAvatar: cachedAIAvatar,
                    cachedUserAvatar: cachedUserAvatar,
                    aiAvatarURL: aiAvatarURL
                )
                .id(message.id)
            }
        }
    }

    private var loadingIndicatorView: some View {
        HStack(alignment: .firstTextBaseline, spacing: Constants.messageSpacing) {
            // 使用缓存的头像视图
            if let cachedAvatar = cachedAIAvatar {
                cachedAvatar
            } else {
                AIAvatarView(size: Constants.avatarSize, url: aiAvatarURL)
            }

            HStack(spacing: 6) {
                ProgressView()
                    .scaleEffect(0.6)
                    .controlSize(.small)
                Text("ai.chat.thinking".localized())
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 40)
        }
        .padding(.vertical, Constants.messageVerticalPadding)
    }

    // MARK: - Methods

    private func scrollToBottom(proxy: ScrollViewProxy) {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(Constants.scrollDelay * 1_000_000_000))
            guard let lastMessage = chatState.messages.last else { return }
            withAnimation(.easeOut(duration: Constants.scrollAnimationDuration)) {
                proxy.scrollTo(lastMessage.id, anchor: .bottom)
            }
        }
    }
}
