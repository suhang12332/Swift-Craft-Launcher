//
//  AIChatWindow.swift
//  SwiftCraftLauncher
//
//  Created by AI Assistant
//

import SwiftUI
import UniformTypeIdentifiers

/// AI 对话窗口视图
struct AIChatWindowView: View {
    @ObservedObject var chatState: ChatState
    @StateObject private var playerListViewModel = PlayerListViewModel()
    @State private var inputText = ""
    @State private var pendingAttachments: [MessageAttachmentType] = []
    @FocusState private var isInputFocused: Bool
    @State private var isFilePickerPresented = false

    // MARK: - Constants
    private enum Constants {
        static let avatarSize: CGFloat = 32
        static let messageFontSize: CGFloat = 13
        static let timestampFontSize: CGFloat = 10
        static let inputFontSize: CGFloat = 14
        static let messageCornerRadius: CGFloat = 10
        static let inputCornerRadius: CGFloat = 12
        static let messageMaxWidth: CGFloat = 500
        static let messageSpacing: CGFloat = 16
        static let messageVerticalPadding: CGFloat = 2
        static let inputHorizontalPadding: CGFloat = 16
        static let inputVerticalPadding: CGFloat = 12
        static let scrollDelay: TimeInterval = 0.1
        static let scrollAnimationDuration: TimeInterval = 0.3
    }

    var body: some View {
        VStack(spacing: 0) {
            // 消息列表
            GeometryReader { geometry in
                ScrollViewReader { proxy in
                    ScrollView {
                        if chatState.messages.isEmpty {
                            // 空消息时显示欢迎语，使用固定高度容器实现垂直居中
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
                    .background(.white)
                    // 滚动到底部：监听消息ID变化（新消息）和内容长度变化（流式更新）
                    .onChange(of: chatState.messages.last?.id) { _, newValue in
                        if newValue != nil {
                            scrollToBottom(proxy: proxy)
                        }
                    }
                    .onChange(of: chatState.messages.last?.content.count ?? 0) { oldValue, newValue in
                        // 流式更新时滚动
                        if chatState.isSending && newValue > oldValue && newValue > 0 {
                            scrollToBottom(proxy: proxy)
                        }
                    }
                    .onChange(of: chatState.isSending) { oldValue, newValue in
                        // 发送完成时滚动
                        if oldValue && !newValue {
                            scrollToBottom(proxy: proxy)
                        }
                    }
                }
            }
            .background(.white)

            Divider()

            // 待发送附件预览
            if !pendingAttachments.isEmpty {
                attachmentPreviewSection
            }

            inputAreaView
        }

        .frame(minWidth: 500, minHeight: 600)
        .fileImporter(
            isPresented: $isFilePickerPresented,
            allowedContentTypes: [.text, .pdf, .json, .plainText, .log],
            allowsMultipleSelection: true
        ) { result in
            handleFileSelection(result)
        }
        .onAppear {
            isInputFocused = true
        }
    }

    // MARK: - Computed Properties

    private var canSend: Bool {
        !chatState.isSending && (!inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !pendingAttachments.isEmpty)
    }

    // MARK: - View Components

    private var attachmentPreviewSection: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(pendingAttachments.enumerated()), id: \.offset) { index, attachment in
                        AttachmentPreview(attachment: attachment) {
                            pendingAttachments.remove(at: index)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .background(.white)
            Divider()
        }
    }

    private var welcomeView: some View {
        VStack(spacing: 16) {
            if let player = playerListViewModel.currentPlayer {
                Text(String(format: "ai.chat.welcome.message".localized(), player.name))
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)

                Text("ai.chat.welcome.description".localized())
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
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
                    currentPlayer: playerListViewModel.currentPlayer
                )
                .id(message.id)
            }
        }
    }

    private var loadingIndicatorView: some View {
        HStack(alignment: .firstTextBaseline, spacing: Constants.messageSpacing) {
            AIAvatarView(size: Constants.avatarSize)

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

    private var inputAreaView: some View {
        HStack(spacing: Constants.messageSpacing) {
            Button(action: { isFilePickerPresented = true }, label: {
                Image(systemName: "paperclip")
                    .font(.system(size: Constants.inputFontSize))
                    .foregroundStyle(.secondary)
            })
            .buttonStyle(.plain)
            .disabled(chatState.isSending)

            TextField("ai.chat.input.placeholder".localized(), text: $inputText, axis: .vertical)
                .textFieldStyle(.plain)
                .focused($isInputFocused)
                .lineLimit(1...6)
                .onSubmit {
                    if canSend {
                        sendMessage()
                    }
                }
                .disabled(chatState.isSending)

            Button(action: { sendMessage() }, label: {
                Image(systemName: "arrow.up.circle")
                    .font(.system(size: Constants.inputFontSize))
                    .foregroundStyle(canSend ? .blue : .secondary)
            })
            .buttonStyle(.plain)
            .disabled(!canSend)
        }
        .padding(.horizontal, Constants.inputHorizontalPadding)
        .padding(.vertical, Constants.inputVerticalPadding)
        .background(Color(NSColor.textBackgroundColor))
    }

    // MARK: - Methods

    private func handleFileSelection(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result else { return }

        for url in urls {
            guard url.startAccessingSecurityScopedResource() else { continue }
            defer { url.stopAccessingSecurityScopedResource() }

            // 过滤掉图片类型，只允许非图片文件
            let isImage = UTType(filenameExtension: url.pathExtension)?.conforms(to: .image) ?? false
            if isImage {
                continue
            }
            // 只添加非图片文件
            let attachment: MessageAttachmentType = .file(url, url.lastPathComponent)
            pendingAttachments.append(attachment)
        }
    }

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard canSend else { return }

        let attachments = pendingAttachments
        inputText = ""
        pendingAttachments = []

        Task {
            await AIChatManager.shared.sendMessage(text, attachments: attachments, chatState: chatState)
        }
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

// MARK: - Helper Views

private struct AIAvatarView: View {
    let size: CGFloat

    var body: some View {
        MinecraftSkinUtils(
            type: .asset,
            src: "steve",
            size: size
        )
    }
}

/// 消息气泡视图
struct MessageBubble: View {
    let message: ChatMessage
    let currentPlayer: Player?

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
        AIAvatarView(size: Constants.avatarSize)
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
        if let player = currentPlayer {
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
        .frame(width: 600, height: 500)
}
