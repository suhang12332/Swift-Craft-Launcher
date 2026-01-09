import SwiftUI

/// 显示开源协议的视图
public struct LicenseView: View {
    @State private var licenseText: String = ""
    @State private var isLoading: Bool = true
    private let gitHubService = GitHubService.shared

    public init() {}

    public var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .controlSize(.small)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if !licenseText.isEmpty {
                ScrollView {
                    Text(licenseText)
                        .font(.system(size: 11, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .frame(width: 570)
                }
            } else {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 32))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task {
            await loadLicense()
        }
        .windowReferenceTracking {
            clearAllData()
        }
    }

    private func loadLicense() async {
        do {
            licenseText = try await gitHubService.fetchLicenseText()
        } catch {}
        isLoading = false
    }

    /// 清理所有数据
    private func clearAllData() {
        licenseText = ""
        isLoading = true
    }
}

#Preview {
    LicenseView()
}
