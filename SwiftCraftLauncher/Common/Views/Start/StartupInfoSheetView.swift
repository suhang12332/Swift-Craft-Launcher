//
//  StartupInfoSheetView.swift
//  SwiftCraftLauncher
//
//  Created by su on 2025/1/12.
//

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
                            // 显示从API获取的公告内容
                            Text(
                                String.localizedStringWithFormat(
                                    announcementData.content,
                                    Bundle.main.appName,
                                    Bundle.main.appName,
                                    Bundle.main.appName
                                )
                            )
                            .font(.body)
                            .multilineTextAlignment(.leading)
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)

                            // 作者信息
                            if !announcementData.author.isEmpty {
                                Text(announcementData.author)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(.top, 8)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)  // 为滚动条留出空间
                }
            },
            footer: {
                HStack {
                    Spacer()

                    Button("startup.info.understand".localized()) {
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                }
            }
        )
        //        .frame(width: 600, height: 500)
        .onAppear {
            // 设置窗口属性
            if let window = NSApplication.shared.windows.last {
                window.level = .floating
                window.center()
            }
        }
    }
}

// MARK: - Preview
#Preview {
    StartupInfoSheetView(announcementData: nil)
}
