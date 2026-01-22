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

    // 用于防抖和避免循环更新的状态
    @State private var lastContentLength: Int = 0
    @State private var scrollTask: Task<Void, Never>?
    @State private var periodicScrollTask: Task<Void, Never>?

    private enum Constants {
        static let avatarSize: CGFloat = 32
        static let messageSpacing: CGFloat = 16
        static let messageVerticalPadding: CGFloat = 2
        static let scrollDelay: TimeInterval = 0.1
        static let scrollAnimationDuration: TimeInterval = 0.3
        static let scrollThrottleInterval: TimeInterval = 0.2 // 防抖间隔
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
                // 滚动到底部：优化 - 使用防抖机制避免频繁更新导致的循环
                .onChange(of: chatState.messages.count) { _, _ in
                    // 新消息时滚动
                    if chatState.messages.last != nil {
                        scheduleScroll(proxy: proxy)
                    }
                }
                .onChange(of: chatState.messages.last?.id) { _, _ in
                    // 最后一条消息的 ID 变化时（新消息），重置内容长度跟踪并滚动
                    if let lastMessage = chatState.messages.last {
                        lastContentLength = lastMessage.content.count
                        scheduleScroll(proxy: proxy)
                    }
                }
                .onChange(of: chatState.isSending) { oldValue, newValue in
                    if !oldValue && newValue {
                        // 开始发送时，启动定期滚动检查
                        startPeriodicScrollCheck(proxy: proxy)
                    } else if oldValue && !newValue {
                        // 发送完成时，停止定期滚动检查并滚动到底部
                        stopPeriodicScrollCheck()
                        scheduleScroll(proxy: proxy)
                    }
                }
                .onAppear {
                    // 视图出现时，如果正在发送，启动定期滚动检查
                    if chatState.isSending {
                        startPeriodicScrollCheck(proxy: proxy)
                    }
                }
                .onDisappear {
                    // 视图消失时，停止所有滚动任务
                    stopPeriodicScrollCheck()
                    scrollTask?.cancel()
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

    /// 调度滚动到底部（带防抖）
    private func scheduleScroll(proxy: ScrollViewProxy) {
        // 取消之前的任务
        scrollTask?.cancel()

        // 创建新的防抖任务
        scrollTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(Constants.scrollThrottleInterval * 1_000_000_000))
            guard !Task.isCancelled else { return }
            scrollToBottom(proxy: proxy)
        }
    }

    /// 启动定期滚动检查（用于流式更新）
    private func startPeriodicScrollCheck(proxy: ScrollViewProxy) {
        stopPeriodicScrollCheck()

        periodicScrollTask = Task { @MainActor in
            while !Task.isCancelled && chatState.isSending {
                // 检查内容是否更新
                if let lastMessage = chatState.messages.last,
                   lastMessage.content.count > lastContentLength {
                    lastContentLength = lastMessage.content.count
                    scrollToBottom(proxy: proxy)
                }

                // 每 0.3 秒检查一次
                try? await Task.sleep(nanoseconds: 300_000_000)
            }
        }
    }

    /// 停止定期滚动检查
    private func stopPeriodicScrollCheck() {
        periodicScrollTask?.cancel()
        periodicScrollTask = nil
    }

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
