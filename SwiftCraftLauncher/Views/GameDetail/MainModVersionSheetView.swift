//
//  MainModVersionSheetView.swift
//  SwiftCraftLauncher
//
//  Created by su on 2025/1/1.
//

import SwiftUI

struct MainModVersionSheetView: View {
    @ObservedObject var viewModel: MainModVersionSheetViewModel
    let projectDetail: ModrinthProjectDetail
    @Binding var isDownloading: Bool
    @State private var error: GlobalError?

    let onDownload: () async -> Void

    var body: some View {
        CommonSheetView(
            header: {
                Text("main_mod.version.title".localized())
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
            },
            body: {
                if viewModel.isLoadingVersions {
                    ProgressView().frame(height: 100).controlSize(.small)
                } else {
                    ModrinthProjectTitleView(projectDetail: projectDetail)
                    VStack(alignment: .leading, spacing: 12) {
                        if !viewModel.availableVersions.isEmpty {
                            Text(projectDetail.title)
                                .font(.headline)
                                .foregroundColor(.primary)
                            Picker(
                                "main_mod.version.picker".localized(),
                                selection: Binding(
                                    get: {
                                        viewModel.selectedVersionId
                                            ?? viewModel.availableVersions.first?.id ?? ""
                                    },
                                    set: {
                                        viewModel.selectedVersionId = $0
                                    }
                                )
                            ) {
                                ForEach(viewModel.availableVersions, id: \.id) { version in
                                    Text(version.name).tag(version.id)
                                }
                            }
                            .pickerStyle(.menu)
                            .font(.subheadline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        } else {
                            Text("main_mod.version.no_versions".localized())
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            },
            footer: {
                HStack {
                    Button("common.close".localized()) {
                        viewModel.showMainModVersionSheet = false
                    }
                    Spacer()

                    if !viewModel.availableVersions.isEmpty {
                        Button {
                            Task {
                                await onDownload()
                            }
                        } label: {
                            if isDownloading {
                                ProgressView().controlSize(.small)
                            } else {
                                Text("main_mod.version.download".localized())
                            }
                        }
                        .keyboardShortcut(.defaultAction)
                        .disabled(isDownloading)
                    }
                }
            }
        )
        .alert(
            "error.notification.download.title".localized(),
            isPresented: .constant(error != nil)
        ) {
            Button("common.close".localized()) {
                error = nil
            }
        } message: {
            if let error = error {
                Text(error.chineseMessage)
            }
        }
    }
}
