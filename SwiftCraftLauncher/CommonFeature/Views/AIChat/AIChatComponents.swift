//
//  AIChatComponents.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import AppKit
import SwiftMarkDownUI
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
struct MessageBubble: View, Equatable {
    let message: ChatMessage
    let currentPlayer: Player?
    let cachedAIAvatar: AnyView?
    let cachedUserAvatar: AnyView?
    let aiAvatarURL: String

    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.message == rhs.message
            && lhs.aiAvatarURL == rhs.aiAvatarURL
    }

    private enum Constants {
        static let avatarSize: CGFloat = 32
        static let messageMaxWidth: CGFloat = 500
        static let messageSpacing: CGFloat = 16
        static let messageVerticalPadding: CGFloat = 2
        static let timestampHorizontalPadding: CGFloat = 4
        static let timestampTopPadding: CGFloat = 2
        static let attachmentSpacing: CGFloat = 6
        static let attachmentBottomPadding: CGFloat = 4
    }

    var body: some View {
        HStack(alignment: .top, spacing: Constants.messageSpacing) {
            if message.role == .user {
                messageContentView(alignment: .trailing)
                userAvatarView
            } else {
                aiAvatarView
                messageContentView(alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)
        .padding(.vertical, Constants.messageVerticalPadding)
    }

    @ViewBuilder private var aiAvatarView: some View {
        if let cachedAvatar = cachedAIAvatar {
            cachedAvatar
        } else {
            AIAvatarView(size: Constants.avatarSize, url: aiAvatarURL)
        }
    }

    private func messageContentView(alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 4) {
            if !message.attachments.isEmpty {
                attachmentsView(alignment: alignment)
                    .padding(.bottom, message.content.isEmpty ? 0 : Constants.attachmentBottomPadding)
            }

            if !message.content.isEmpty {
                messageTextBubble(alignment: alignment)
            }

            timestampView(alignment: alignment)
        }
    }

    private func attachmentsView(alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: Constants.attachmentSpacing) {
            ForEach(Array(message.attachments.enumerated()), id: \.offset) { _, attachment in
                AttachmentView(attachment: attachment)
            }
        }
        .fixedSize()
    }

    private func messageTextBubble(alignment: HorizontalAlignment) -> some View {
        let textAlignment: Alignment = alignment == .trailing ? .trailing : .leading
        return MixedMarkdownView(message.content)
            .font(.body)
            .textSelection(.enabled)
            .foregroundStyle(.primary)
            .frame(maxWidth: Constants.messageMaxWidth, alignment: textAlignment)
    }

    private func timestampView(alignment _: HorizontalAlignment) -> some View {
        Text(message.timestamp, style: .time)
            .font(.caption2)
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
                .font(.caption)
                .frame(width: Constants.avatarSize, height: Constants.avatarSize)
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
                    .font(.title3)
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
                    .font(.body)
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
private struct AttachmentView: View {
    let attachment: MessageAttachmentType

    private enum Constants {
        static let fileIconSize: CGFloat = 32
        static let fileSpacing: CGFloat = 8
        static let filePadding: CGFloat = 10
        static let fileCornerRadius: CGFloat = 8
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
                .font(.title3)
                .foregroundStyle(.blue)
                .frame(width: Constants.fileIconSize, height: Constants.fileIconSize)

            VStack(alignment: .leading, spacing: 2) {
                Text(fileName)
                    .font(.subheadline)
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
        .fixedSize()
        .contentShape(Rectangle())
        .onTapGesture {
            NSWorkspace.shared.activateFileViewerSelecting([url])
        }
    }
}
