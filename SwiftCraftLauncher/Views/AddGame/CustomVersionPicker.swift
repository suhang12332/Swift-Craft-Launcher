import SwiftUI

private enum Constants {
    static let versionGridColumns = 6
    static let versionPopoverMinWidth: CGFloat = 320
    static let versionPopoverMaxHeight: CGFloat = 360
    static let versionButtonPadding: CGFloat = 6
    static let versionButtonVerticalPadding: CGFloat = 3
}

struct CustomVersionPicker: View {
    @Binding var selected: String
    let availableVersions: [String]
    @Binding var time: String
    let onVersionSelected: (String) async -> String  // 新增：版本选择回调，返回时间信息
    @State private var showMenu = false
    @State private var error: GlobalError?

    private var groupedVersions: [(String, [String])] {
        let dict = Dictionary(grouping: availableVersions) { version in
            version.split(separator: ".").prefix(2).joined(separator: ".")
        }
        return dict.sorted {
            let lhs = $0.key.split(separator: ".").compactMap { Int($0) }
            let rhs = $1.key.split(separator: ".").compactMap { Int($0) }
            return lhs.lexicographicallyPrecedes(rhs)
        }
        .reversed()
    }

    private let columns = Array(
        repeating: GridItem(.flexible(), spacing: 8),
        count: Constants.versionGridColumns
    )

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("game.form.version".localized())
                    .font(.subheadline)
                    .foregroundColor(.primary)
                Spacer()
                Text(
                    time.isEmpty ? "" : "release.time.prefix".localized() + time
                )
                .font(.subheadline)
                .foregroundColor(.secondary)
            }
            versionInput
        }
        .alert(
            "error.notification.validation.title".localized(),
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

    private var versionInput: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color(.quaternaryLabelColor), lineWidth: 1)
                .background(Color(.textBackgroundColor))
            HStack {
                if selected.isEmpty {
                    Text("game.form.version.placeholder".localized())
                        .foregroundColor(.primary)
                        .padding(.horizontal, 8)
                } else {
                    Text(selected).foregroundColor(.primary)
                        .padding(.horizontal, 8)
                }
                Spacer()
            }
        }
        .frame(height: 22)
        .onTapGesture {
            if !availableVersions.isEmpty {
                showMenu.toggle()
            } else {
                handleEmptyVersionsError()
            }
        }
        .popover(isPresented: $showMenu, arrowEdge: .trailing) {
            versionPopoverContent
        }
    }

    private var versionPopoverContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(groupedVersions, id: \.0) { (major, versions) in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(major)
                            .font(.headline)
                            .padding(.vertical, 2)
                        LazyVGrid(
                            columns: columns,
                            alignment: .leading,
                            spacing: 8
                        ) {
                            ForEach(versions, id: \.self) { version in
                                versionButton(for: version)
                            }
                        }
                    }
                }
            }
            .padding(12)
        }
        .frame(
            minWidth: Constants.versionPopoverMinWidth,
            maxHeight: Constants.versionPopoverMaxHeight
        )
    }

    private func versionButton(for version: String) -> some View {
        Button(version) {
            selected = version
            showMenu = false
            // 使用版本时间映射来设置时间信息
            Task {
                time = await onVersionSelected(version)
            }
        }
        .padding(.horizontal, Constants.versionButtonPadding)
        .padding(.vertical, Constants.versionButtonVerticalPadding)
        .font(.subheadline)
        .cornerRadius(4)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(
                    selected == version
                        ? Color.accentColor : Color.gray.opacity(0.15)
                )
        )
        .foregroundStyle(selected == version ? .white : .primary)
        .buttonStyle(.plain)
        .fixedSize()
    }

    private func handleEmptyVersionsError() {
        let globalError = GlobalError.resource(
            chineseMessage: "没有可用的版本",
            i18nKey: "error.resource.no_versions_available",
            level: .notification
        )
        Logger.shared.error("版本选择器错误: \(globalError.chineseMessage)")
        GlobalErrorHandler.shared.handle(globalError)
        error = globalError
    }

    private func handleVersionSelectionError(_ error: Error) {
        let globalError = GlobalError.from(error)
        Logger.shared.error("版本选择错误: \(globalError.chineseMessage)")
        GlobalErrorHandler.shared.handle(globalError)
        self.error = globalError
    }
}
