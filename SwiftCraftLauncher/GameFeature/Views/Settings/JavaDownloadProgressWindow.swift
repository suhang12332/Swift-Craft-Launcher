//
//  JavaDownloadProgressWindow.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

// A window displaying Java runtime download progress and status.
import SwiftUI

struct JavaDownloadProgressWindow: View {
    @Environment(DIContainer.self)
    private var container
    var downloadState: JavaDownloadState
    @Environment(\.dismiss)
    private var dismiss

    var body: some View {
        VStack {
            if downloadState.hasError {
                DownloadItemView(
                    icon: "exclamationmark.triangle.fill",
                    title: downloadState.version,
                    subtitle: downloadState.errorMessage,
                    status: .error,
                    onCancel: {
                        container.system.javaDownloadManager.retryDownload()
                    },
                    downloadState: downloadState,
                )
            } else if downloadState.isDownloading {
                DownloadItemView(
                    icon: "cup.and.saucer.fill",
                    title: downloadState.version,
                    subtitle: downloadState.currentFile.isEmpty ? "Preparing..." : downloadState.currentFile,
                    status: .downloading(progress: downloadState.progress),
                    onCancel: {
                        container.system.javaDownloadManager.cancelDownload()
                    },
                    downloadState: downloadState,
                )
            }
        }
        .padding()
        .frame(width: AuxiliaryWindowID.javaDownload.defaultSize.width, height: AuxiliaryWindowID.javaDownload.defaultSize.height)
        .onAppear {
            container.system.javaDownloadManager.setDismissCallback {
                dismiss()
            }
        }
    }
}

/// A single download item row with icon, progress, and action button.
private struct DownloadItemView: View {
    let icon: String
    let title: String
    let subtitle: String
    let status: DownloadStatus
    let onCancel: () -> Void
    let downloadState: JavaDownloadState?

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Image(systemName: icon)
                    .font(.title)
                    .foregroundColor(iconColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    Spacer()
                    Text("\(Int((downloadState?.progress ?? 0) * 100))%")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                if case let .downloading(progress) = status {
                    VStack(alignment: .leading, spacing: 2) {
                        ProgressView(value: progress)
                            .progressViewStyle(LinearProgressViewStyle())
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: onCancel) {
                Image(systemName: buttonIcon)
                    .foregroundColor(buttonColor)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 8)
    }

    private var iconColor: Color {
        switch status {
        case .downloading:
            return .accentColor
        case .error:
            return .red
        default:
            return .accentColor
        }
    }

    private var buttonIcon: String {
        switch status {
        case .downloading:
            return "xmark.circle.fill"
        case .error:
            return "arrow.clockwise.circle.fill"
        case .completed, .cancelled:
            return "xmark.circle.fill"
        }
    }

    private var buttonColor: Color {
        switch status {
        case .downloading:
            return .secondary
        case .error:
            return .blue
        case .completed, .cancelled:
            return .secondary
        }
    }
}

/// Represents the current state of a download operation.
enum DownloadStatus {
    case downloading(progress: Double)
    case completed
    case error
    case cancelled
}
