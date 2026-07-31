//
//  ModPackURLDownloadView.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import SwiftUI

/// A view for downloading a modpack from a user-provided URL.
struct ModPackURLDownloadView: View {
    let onDownloadComplete: (URL) -> Void
    let onCancel: () -> Void
    let isFormValid: Binding<Bool>
    let triggerConfirm: Binding<Bool>
    let triggerCancel: Binding<Bool>
    @Binding var isDownloading: Bool

    @State private var viewModel = ModPackURLDownloadViewModel()
    @Environment(\.dismiss)
    private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if viewModel.isDownloading {
                DownloadingProgressView(
                    progress: viewModel.downloadProgress,
                    totalSize: viewModel.downloadTotalSize,
                    title: "modpack.processing.title".localized(),
                    subtitle: "modpack.processing.subtitle.remote".localized(),
                )
            } else {
                urlInputView
            }
        }
        .onChange(of: viewModel.urlString) { _, _ in
            isFormValid.wrappedValue = viewModel.isURLValid
        }
        .onChange(of: triggerConfirm.wrappedValue) { _, newValue in
            if newValue {
                triggerConfirm.wrappedValue = false
                if viewModel.isURLValid && !viewModel.isDownloading {
                    startDownload()
                }
            }
        }
        .onChange(of: triggerCancel.wrappedValue) { _, newValue in
            if newValue {
                triggerCancel.wrappedValue = false
                if viewModel.isDownloading {
                    viewModel.cancel()
                    isDownloading = false
                } else {
                    onCancel()
                }
            }
        }
    }

    private var urlInputView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("modpack.url_download.description".localized())
                .font(.subheadline)
                .foregroundColor(.secondary)

            TextField("modpack.url_download.placeholder".localized(), text: $viewModel.urlString)
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled()
                .onSubmit {
                    if viewModel.isURLValid {
                        startDownload()
                    }
                }
        }
    }

    private func startDownload() {
        viewModel.startDownload { fileURL in
            isDownloading = false
            onDownloadComplete(fileURL)
        }
        isDownloading = true
    }
}
