import SwiftUI
import AppKit

/// 创建房间窗口视图（类似WiFi密码输入窗口）
struct CreateRoomWindowView: View {
    @StateObject private var viewModel = EasyTierViewModel()
    @State private var roomCode: String = ""
    @State private var isConnecting: Bool = false
    @State private var isCreating: Bool = false

    var body: some View {
        VStack(spacing: 20) {
            HStack(spacing: 12) {
                Image(systemName: "house.circle")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 54, height: 54)
                    .foregroundColor(.accentColor)
                VStack(alignment: .leading, spacing: 8) {
                    Text("easytier.create.room.title".localized())
                        .font(.headline)
                    Text("easytier.create.room.description".localized())
                        .font(.caption)
                }.padding(.leading, 4)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack(spacing: 8) {
                Text("easytier.room.code".localized())
                    .font(.headline)
                    .foregroundColor(.secondary)

                HStack(spacing: 8) {
                    TextField("easytier.room.code.generating".localized(), text: $roomCode)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                        .disabled(true)

                    if !roomCode.isEmpty {
                        ShareLink(item: roomCode) {
                            Image(systemName: "square.and.arrow.up")
                        }
                        .buttonStyle(.bordered)
                        .help("common.share".localized())

                        Button(action: createRoom) {
                            Image(systemName: "arrow.clockwise")
                        }
                        .buttonStyle(.bordered)
                        .help("common.refresh".localized())
                    }
                }
            }

            HStack {
                // 取消按钮
                Button(action: {
                    TemporaryWindowManager.shared.closeWindow(withTitle: "easytier.create.room.window.title".localized())
                }, label: {
                    Text("common.cancel".localized())
                })
                .buttonStyle(.bordered)
                .disabled(isConnecting)
                Spacer()
                // 连接按钮
                Button(action: {
                    Task { await connect() }
                }, label: {
                    if isConnecting {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Text("menubar.room.create".localized())
                    }
                })
                .buttonStyle(.borderedProminent)
                .disabled(roomCode.isEmpty || isConnecting)
            }
        }
        .frame(width: 400, height: 100)
        .padding(20)
        .onAppear {
            createRoom()
        }
        .onChange(of: viewModel.networkStatus) { _, newStatus in
            if case .connected = newStatus {
                // 连接成功，设置房间类型为创建，关闭窗口
                EasyTierManager.shared.setRoomCreated()
                TemporaryWindowManager.shared.closeWindow(withTitle: "easytier.create.room.window.title".localized())
            }
        }
    }

    private func createRoom() {
        isCreating = true
        viewModel.createRoom()
        if let room = viewModel.currentRoom {
            roomCode = room.roomCode
        }
        isCreating = false
    }

    private func connect() async {
        isConnecting = true

        await viewModel.startNetwork()

        isConnecting = false
    }
}
