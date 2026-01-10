import SwiftUI

/// 加入房间窗口视图（类似WiFi密码输入窗口）
struct JoinRoomWindowView: View {
    @StateObject private var viewModel = EasyTierViewModel()
    @State private var roomCode: String = ""
    @State private var isConnecting: Bool = false
    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        VStack(spacing: 20) {
            HStack(spacing: 12) {
                Image(systemName: "house.circle")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 54, height: 54)
                    .foregroundColor(.accentColor)
                VStack(alignment: .leading, spacing: 8) {
                    Text("easytier.join.room.title".localized())
                        .font(.headline)
                    Text("easytier.join.room.description".localized())
                        .font(.caption)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                }.padding(.leading, 4)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack(spacing: 8) {
                Text("easytier.room.code".localized())
                    .font(.headline)
                    .foregroundColor(.secondary)

                TextField("easytier.room.code.placeholder".localized(), text: $roomCode)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                    .focused($isTextFieldFocused)
                    .disabled(isConnecting)
            }

            HStack {
                // 取消按钮
                Button(action: {
                    TemporaryWindowManager.shared.closeWindow(withTitle: "easytier.join.room.window.title".localized())
                }, label: {
                    Text("common.cancel".localized())
                })
                .buttonStyle(.bordered)
                .disabled(isConnecting)
                Spacer()
                // 加入按钮
                Button(action: {
                    Task { await connect() }
                }, label: {
                    if isConnecting {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Text("easytier.join".localized())
                    }
                })
                .buttonStyle(.borderedProminent)
                .disabled(roomCode.isEmpty || isConnecting)
            }
        }
        .frame(width: 400, height: 130)
        .padding(20)
        .onAppear {
            isTextFieldFocused = true
        }
        .windowReferenceTracking {
            clearAllData()
        }
        .onChange(of: viewModel.networkStatus) { _, newStatus in
            if case .connected = newStatus {
                // 连接成功，设置房间类型为加入，关闭窗口
                EasyTierManager.shared.setRoomJoined()
                TemporaryWindowManager.shared.closeWindow(withTitle: "easytier.join.room.window.title".localized())
            }
        }
    }

    private func connect() async {
        isConnecting = true
        viewModel.inputRoomCode = roomCode

        await viewModel.startNetwork()

        isConnecting = false
    }

    /// 清理所有数据
    private func clearAllData() {
        roomCode = ""
        isConnecting = false
    }
}
