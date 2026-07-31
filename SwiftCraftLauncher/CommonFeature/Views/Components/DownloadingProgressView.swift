//
//  DownloadingProgressView.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import SwiftUI

/// A reusable view for displaying download progress with circular progress indicator.
struct DownloadingProgressView: View {
    let progress: Int64
    let totalSize: Int64
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 24) {
            ProgressView(
                value: Double(max(progress, 0)),
                total: Double(max(totalSize, 100)),
            )
            .progressViewStyle(.circular)
            .controlSize(.extraLarge)

            Text(title)
                .font(.headline)
                .foregroundColor(.primary)

            Text(subtitle)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Text(ByteCountFormatter.string(
                fromByteCount: progress,
                countStyle: .file,
            ) + " / " + ByteCountFormatter.string(
                fromByteCount: totalSize,
                countStyle: .file,
            ))
            .font(.subheadline)
            .foregroundColor(.secondary)
        }
        .padding()
    }
}
