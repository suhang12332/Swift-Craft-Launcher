//
//  StartupInfoSheetView.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import SwiftMarkDownUI
import SwiftUI

/// A sheet view for displaying startup information and announcements.
struct StartupInfoSheetView: View {

    @Environment(\.dismiss)
    private var dismiss

    let announcementData: AnnouncementData?

    var body: some View {
        CommonSheetView(
            header: {
                if let title = announcementData?.title {
                    Text(title)
                        .font(.title2)
                        .fontWeight(.semibold)
                }
            },
            body: {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
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
                    .padding(.horizontal, 4)
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
                        AppServices.announcementStateManager.markAnnouncementAcknowledgedForCurrentVersion()
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                }
            }
        )
    }
}
