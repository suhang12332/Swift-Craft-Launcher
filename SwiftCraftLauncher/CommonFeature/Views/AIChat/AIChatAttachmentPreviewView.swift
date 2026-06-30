//
//  AIChatAttachmentPreviewView.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import SwiftUI

/// Displays a horizontal scrollable preview of pending attachments.
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
