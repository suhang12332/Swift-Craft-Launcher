//
//  AIChatAttachmentPreviewView.swift
//  SwiftCraftLauncher
//
//

import SwiftUI

/// AI 聊天附件预览区域视图
struct AIChatAttachmentPreviewView: View {
    let attachments: [MessageAttachmentType]
    let onRemove: (Int) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(attachments.enumerated()), id: \.offset) { index, attachment in
                        AttachmentPreview(attachment: attachment) {
                            onRemove(index)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            Divider()
        }
    }
}
