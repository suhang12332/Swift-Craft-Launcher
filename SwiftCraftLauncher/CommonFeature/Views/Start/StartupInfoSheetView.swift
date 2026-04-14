//
//  StartupInfoSheetView.swift
//  SwiftCraftLauncher
//
//  Created by su on 2025/1/12.
//

import SwiftMarkDownUI
import SwiftUI

/// 启动信息提示Sheet视图
struct StartupInfoSheetView: View {

    // MARK: - Properties
    @Environment(\.dismiss)
    private var dismiss

    let announcementData: AnnouncementData?

    // MARK: - Body
    var body: some View {
        CommonSheetView(
            header: {
                VStack(spacing: 12) {
                    // 标题
                    if let title = announcementData?.title {
                        Text(title)
                            .font(.title2)
                            .fontWeight(.semibold)
                    }
                }
            },
            body: {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // 应用图标
                        HStack {
                            Spacer()
                            if let appIcon = NSApplication.shared.applicationIconImage {
                                Image(nsImage: appIcon)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 64, height: 64)
                            }
                            Spacer()
                        }
                        .padding(.bottom, 8)

                        // 主要信息内容
                        if let announcementData = announcementData {
                            let placeholderPattern = /%(\d+\$)?@/
                            let localizedContent = announcementData.content.replacing(
                                placeholderPattern,
                                with: Bundle.main.appName
                            )
                            MixedMarkdownView(localizedContent)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 4)  // 为滚动条留出空间
                }
            },
            footer: {
                HStack {
                    if let author = announcementData?.author, !author.isEmpty {
                        Text(author)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()

                    Button("startup.info.understand".localized()) {
                        AnnouncementStateManager.shared.markAnnouncementAcknowledgedForCurrentVersion()
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                }
            }
        )
    }
}

// MARK: - Preview
#Preview {
    StartupInfoSheetView(
        announcementData: AnnouncementData(
            title: "SwiftCraft Launcher v1.2.0",
            content:
                """
                ### 欢迎使用 %@

                本次更新包含以下内容：

                - 优化启动性能，减少首次加载等待时间
                - 改进账号登录稳定性与错误提示
                - 修复已知崩溃问题并提升整体流畅度

                如遇问题，请在设置页面反馈给 **%@ 团队**。

                感谢你对 **%@** 的支持！
                """,
            author: "Swift Craft Launcher Team"
        )
    )
}
