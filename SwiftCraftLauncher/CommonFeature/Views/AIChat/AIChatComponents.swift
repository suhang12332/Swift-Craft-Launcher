//
//  AIChatComponents.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import AppKit
import SwiftUI

/// Displays the AI assistant's avatar.
struct AIAvatarView: View {
    let size: CGFloat
    let url: String

    var body: some View {
        MinecraftSkinUtils(
            type: .url,
            src: url,
            size: size,
        )
    }
}

/// Displays a chat message with avatar, content, and timestamp.
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

    @ViewBuilder private var userMessageView: some View {
        Spacer(minLength: Constants.spacerMinLength)
        messageContentView(alignment: .trailing, isUser: true)
        userAvatarView
    }

    @ViewBuilder private var aiMessageView: some View {
        if let cachedAvatar = cachedAIAvatar {
            cachedAvatar
        } else {
            AIAvatarView(size: Constants.avatarSize, url: aiAvatarURL)
        }
        messageContentView(alignment: .leading, isUser: false)
        Spacer(minLength: Constants.spacerMinLength)
    }

    private func messageContentView(alignment: HorizontalAlignment, isUser _: Bool) -> some View {
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

    private var messageTextBubble: some View {
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

    @ViewBuilder private var userAvatarView: some View {
        if let cachedAvatar = cachedUserAvatar {
            cachedAvatar
        } else if let player = currentPlayer {
            MinecraftSkinUtils(
                type: player.isRemote ? .url : .asset,
                src: player.avatarName,
                size: Constants.avatarSize,
            )
        } else {
            Image(systemName: "person.fill")
                .font(.system(size: Constants.avatarSize))
                .foregroundStyle(.secondary)
        }
    }
}

/// Displays an attachment preview in the input area.
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

/// Displays an attachment within a chat message.
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
        case let .file(url, fileName):
            fileItemView(
                iconName: "doc.fill",
                fileName: fileName,
                fileExtension: url.pathExtension.uppercased(),
                url: url,
            )
        }
    }

    private func fileItemView(
        iconName: String,
        fileName: String,
        fileExtension: String,
        url: URL,
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
