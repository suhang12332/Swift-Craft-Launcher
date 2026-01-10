import SwiftUI

struct JavaDownloadProgressWindow: View {
    @ObservedObject var downloadState: JavaDownloadState
    @Environment(\.dismiss)
    private var dismiss

    var body: some View {
        // 下载项列表
        VStack {
            if downloadState.hasError {
                // 错误状态 要显示重试按钮
                DownloadItemView(
                    icon: "exclamationmark.triangle.fill",
                    title: downloadState.version,
                    subtitle: downloadState.errorMessage,
                    status: .error,
                    onCancel: {
                        JavaDownloadManager.shared.retryDownload()
                    },
                    downloadState: downloadState
                )
            } else if downloadState.isDownloading {
                // 下载中状态
                DownloadItemView(
                    icon: "cup.and.saucer.fill",
                    title: downloadState.version,
                    subtitle: downloadState.currentFile.isEmpty ? "Preparing..." : downloadState.currentFile,
                    status: .downloading(progress: downloadState.progress),
                    onCancel: {
                        JavaDownloadManager.shared.cancelDownload()
                    },
                    downloadState: downloadState
                )
            }
        }
        .padding()
        .onAppear {
            // 设置窗口关闭回调
            JavaDownloadManager.shared.setDismissCallback {
                dismiss()
            }
        }
        .windowReferenceTracking {
            clearAllData()
        }
    }

    /// 清理所有数据
    private func clearAllData() {
        // 窗口引用由 WindowReferenceTracking 自动管理
    }
}

// 下载项视图
struct DownloadItemView: View {
    let icon: String
    let title: String
    let subtitle: String
    let status: DownloadStatus
    let onCancel: () -> Void
    let downloadState: JavaDownloadState?

    var body: some View {
        HStack(spacing: 12) {
            // 图标
            ZStack {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(iconColor)
            }

            // 内容
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

                // 进度条和进度信息（仅在下载中时显示）
                if case .downloading(let progress) = status {
                    VStack(alignment: .leading, spacing: 2) {
                        ProgressView(value: progress)
                            .progressViewStyle(LinearProgressViewStyle())
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // 操作按钮（取消/重试）
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

    private var iconBackgroundColor: Color {
        switch status {
        case .downloading:
            return Color.blue.opacity(0.1)
        case .error:
            return Color.red.opacity(0.1)
        default:
            return .accentColor
        }
    }

    private var buttonIcon: String {
        switch status {
        case .downloading:
            return "xmark.circle.fill"  // 取消图标
        case .error:
            return "arrow.clockwise.circle.fill"  // 重试图标
        case .completed, .cancelled:
            return "xmark.circle.fill"  // 默认关闭图标
        }
    }

    private var buttonColor: Color {
        switch status {
        case .downloading:
            return .secondary  // 取消按钮用次要颜色
        case .error:
            return .blue  // 重试按钮用蓝色
        case .completed, .cancelled:
            return .secondary  // 默认次要颜色
        }
    }
}

// 下载状态枚举
enum DownloadStatus {
    case downloading(progress: Double)
    case completed
    case error
    case cancelled
}
