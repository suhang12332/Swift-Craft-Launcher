//
//  AIChatAttachmentManager.swift
//  SwiftCraftLauncher
//
//

import SwiftUI
import UniformTypeIdentifiers
import AppKit

/// AI 聊天附件管理器
class AIChatAttachmentManager: ObservableObject {
    @Published var pendingAttachments: [MessageAttachmentType] = []

    /// 打开文件选择器
    func openFilePicker(selectedGame: GameVersionInfo?) {
        guard let selectedGame = selectedGame else { return }

        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.text, .pdf, .json, .plainText, .log]

        // 设置初始目录为游戏目录
        let gameDirectory = AppPaths.profileDirectory(gameName: selectedGame.gameName)
        panel.directoryURL = gameDirectory

        panel.begin { [weak self] response in
            if response == .OK {
                let urls = panel.urls
                self?.handleFileSelection(urls)
            }
        }
    }

    /// 处理文件选择
    private func handleFileSelection(_ urls: [URL]) {
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
