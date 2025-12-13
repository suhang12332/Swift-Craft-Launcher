//
//  AIChatModels.swift
//  SwiftCraftLauncher
//
//  Created by AI Assistant
//

import Foundation
import SwiftUI

/// 消息角色
enum MessageRole: String, Codable {
    case user = "user"
    case assistant = "assistant"
    case system = "system"
}

/// 附件类型
enum MessageAttachmentType: Identifiable, Equatable {
    case image(URL)
    case file(URL, String) // URL 和文件名
    
    var id: String {
        switch self {
        case .image(let url):
            return "image_\(url.path)"
        case .file(let url, _):
            return "file_\(url.path)"
        }
    }
}

/// 聊天消息
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

/// 聊天状态
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

// MARK: - Extension for API Conversion

extension ChatMessage {
    /// 转换为 API 角色字符串
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

