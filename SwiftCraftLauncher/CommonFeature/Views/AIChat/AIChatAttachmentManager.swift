//
//  AIChatAttachmentManager.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import SwiftUI

/// Manages pending file attachments for AI chat messages.
class AIChatAttachmentManager: ObservableObject {
    @Published var pendingAttachments: [MessageAttachmentType] = []

    func handleFileSelection(_ urls: [URL]) {
        for url in urls {
            guard url.startAccessingSecurityScopedResource() else { continue }
            defer { url.stopAccessingSecurityScopedResource() }

            let attachment: MessageAttachmentType = .file(url, url.lastPathComponent)
            pendingAttachments.append(attachment)
        }
    }

    func removeAttachment(at index: Int) {
        guard index < pendingAttachments.count else { return }
        pendingAttachments.remove(at: index)
    }

    func clearAll() {
        pendingAttachments.removeAll()
    }
}
