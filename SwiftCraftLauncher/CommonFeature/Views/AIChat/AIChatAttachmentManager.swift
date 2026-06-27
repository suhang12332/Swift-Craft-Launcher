//
//  AIChatAttachmentManager.swift
//  SwiftCraftLauncher
//
//

import SwiftUI

/// AI 聊天附件管理器
class AIChatAttachmentManager: ObservableObject {
    @Published var pendingAttachments: [MessageAttachmentType] = []

    /// 处理文件选择
    func handleFileSelection(_ urls: [URL]) {
        for url in urls {
            guard url.startAccessingSecurityScopedResource() else { continue }
            defer { url.stopAccessingSecurityScopedResource() }

            let attachment: MessageAttachmentType = .file(url, url.lastPathComponent)
            pendingAttachments.append(attachment)
        }
    }

    /// 移除附件
    func removeAttachment(at index: Int) {
        guard index < pendingAttachments.count else { return }
        pendingAttachments.remove(at: index)
    }

    /// 清除所有附件
    func clearAll() {
        pendingAttachments.removeAll()
    }
}
