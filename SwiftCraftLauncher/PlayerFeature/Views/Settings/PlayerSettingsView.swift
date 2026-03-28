import SwiftUI

public struct PlayerSettingsView: View {
    @StateObject private var playerSettings = PlayerSettingsManager.shared
    @State private var isDownloadingAuthlibInjector = false
    @State private var authlibInjectorExists = false

    public init() {}

    public var body: some View {
        let authlibInjectorJarURL = AppPaths.authDirectory.appendingPathComponent(AppConstants.AuthlibInjector.jarFileName)

        Form {
            LabeledContent("settings.player.offline_login".localized()) {
                Toggle(
                    "settings.player.offline_login.toggle".localized(),
                    isOn: $playerSettings.enableOfflineLogin
                )
                .toggleStyle(.checkbox)
            }.labeledContentStyle(.custom)
            LabeledContent("settings.player.authlib_injector".localized()) {
                if authlibInjectorExists {
                    PathBreadcrumbView(path: authlibInjectorJarURL.path)
                } else {
                    Button {
                        Task {
                            await MainActor.run {
                                isDownloadingAuthlibInjector = true
                            }
                            do {
                                let downloadURL = URLConfig.API.AuthlibInjector.download
                                _ = try await DownloadManager.downloadFile(
                                    urlString: downloadURL.absoluteString,
                                    destinationURL: authlibInjectorJarURL,
                                    expectedSha1: nil
                                )
                                await MainActor.run {
                                    authlibInjectorExists = true
                                }
                            } catch {
                                let globalError = GlobalError.download(
                                    chineseMessage: "下载 authlib-injector 失败: \(error.localizedDescription)",
                                    i18nKey: "error.download.authlib_injector_failed",
                                    level: .notification
                                )
                                GlobalErrorHandler.shared.handle(globalError)
                            }
                            await MainActor.run {
                                isDownloadingAuthlibInjector = false
                            }
                        }
                    } label: {
                        HStack(spacing: 8) {
                            if isDownloadingAuthlibInjector {
                                ProgressView().controlSize(.small)
                            } else {
                                Text("global_resource.download".localized())
                            }
                        }
                    }
                    .disabled(isDownloadingAuthlibInjector)
                }
            }
            .labeledContentStyle(.custom)
            .padding(.top, 10)
        }
        .task {
            let authlibInjectorJarURL = AppPaths.authDirectory.appendingPathComponent(AppConstants.AuthlibInjector.jarFileName)
            authlibInjectorExists = FileManager.default.fileExists(atPath: authlibInjectorJarURL.path)
        }
    }
}
