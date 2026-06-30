//
//  AIChatModels.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation
import SwiftUI

/// Identifies the sender of a chat message.
enum MessageRole: String, Codable {
    case user = "user"
    case assistant = "assistant"
    case system = "system"
}

/// Represents an attachment included with a chat message.
enum MessageAttachmentType: Identifiable, Equatable {
    case file(URL, String)

    var id: String {
        switch self {
        case .file(let url, _):
            return "file_\(url.path)"
        }
    }
}

/// A single message in an AI chat conversation.
struct ChatMessage: Identifiable, Equatable {
    let id: UUID
    let role: MessageRole
    var content: String
    let timestamp: Date
    let attachments: [MessageAttachmentType]

    init(
        id: UUID = UUID(),
        role: MessageRole,
        content: String = "",
        timestamp: Date = Date(),
        attachments: [MessageAttachmentType] = []
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.attachments = attachments
    }
}

@MainActor
class ChatState: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var isSending = false

    func addMessage(_ message: ChatMessage) {
        messages.append(message)
    }

    func updateLastMessage(_ content: String) {
        if let lastIndex = messages.indices.last {
            messages[lastIndex].content = content
        }
    }

    func clear() {
        messages.removeAll()
        isSending = false
    }
}

extension ChatMessage {
    /// The role formatted for the chat API request.
    var apiRoleString: String {
        switch role {
        case .user:
            return "user"
        case .assistant:
            return "assistant"
        case .system:
            return "system"
        }
    }
}
