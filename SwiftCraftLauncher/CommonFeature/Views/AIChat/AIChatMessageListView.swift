//
//  AIChatMessageListView.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import SwiftUI

/// Displays the scrollable list of chat messages.
struct AIChatMessageListView: View {
    @ObservedObject var chatState: ChatState
    let currentPlayer: Player?
    let cachedAIAvatar: AnyView?
    let cachedUserAvatar: AnyView?
    let aiAvatarURL: String

    @StateObject private var scrollCoordinator = AIChatScrollCoordinatorViewModel()

    private enum Constants {
        static let avatarSize: CGFloat = 32
        static let messageSpacing: CGFloat = 16
        static let messageVerticalPadding: CGFloat = 2
        static let scrollDelay: TimeInterval = 0.1
        static let scrollAnimationDuration: TimeInterval = 0.3
        static let scrollThrottleInterval: TimeInterval = 0.2
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollViewReader { proxy in
                ScrollView {
                    if chatState.messages.isEmpty {
                        VStack {
                            Spacer()
                            welcomeView
                            Spacer()
                        }
                        .frame(width: geometry.size.width, height: geometry.size.height)
                    } else {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            messageListView

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
                .onChange(of: chatState.messages.count) { _, _ in
                    scrollCoordinator.onMessagesCountChanged(
                        hasLastMessage: chatState.messages.last != nil
                    ) {
                        scrollToBottom(proxy: proxy)
                    }
                }
                .onChange(of: chatState.messages.last?.id) { _, _ in
                    if let lastMessage = chatState.messages.last {
                        scrollCoordinator.onLastMessageChanged(
                            contentLength: lastMessage.content.count
                        ) {
                            scrollToBottom(proxy: proxy)
                        }
                    }
                }
                .onChange(of: chatState.isSending) { oldValue, newValue in
                    scrollCoordinator.onSendingChanged(
                        wasSending: oldValue,
                        isSending: newValue,
                        scrollToBottom: { scrollToBottom(proxy: proxy) },
                        getLastMessageContentLength: { chatState.messages.last?.content.count }
                    )
                }
                .onAppear {
                    scrollCoordinator.onAppearIfSending(
                        isSending: chatState.isSending,
                        scrollToBottom: { scrollToBottom(proxy: proxy) },
                        getLastMessageContentLength: { chatState.messages.last?.content.count }
                    )
                }
                .onDisappear {
                    scrollCoordinator.onDisappear()
                }
            }
        }
    }

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

    private func scrollToBottom(proxy: ScrollViewProxy) {
        guard let lastMessage = chatState.messages.last else { return }
        withAnimation(.easeOut(duration: Constants.scrollAnimationDuration)) {
            proxy.scrollTo(lastMessage.id, anchor: .bottom)
        }
    }
}
