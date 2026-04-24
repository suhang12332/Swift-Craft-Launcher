import SwiftUI

// MARK: - Server Address Chip
struct ServerAddressChip: View {
    let title: String
    let address: String
    let port: Int?
    let isLoading: Bool
    let connectionStatus: ServerConnectionStatus
    let action: (() -> Void)?

    init(
        title: String,
        address: String,
        port: Int? = nil,
        isLoading: Bool,
        connectionStatus: ServerConnectionStatus = .unknown,
        action: (() -> Void)? = nil
    ) {
        self.title = title
        self.address = address
        self.port = port
        self.isLoading = isLoading
        self.connectionStatus = connectionStatus
        self.action = action
    }

    var body: some View {
        Button(action: action ?? {}) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Image(systemName: "server.rack")
                        .font(.caption)
                        .foregroundColor(connectionStatus.statusColor)
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(1)
                        .frame(maxWidth: 150)
                }
                if !address.isEmpty {
                    if let port, port > 0 {
                        Text(address + ":" + String(port))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .frame(maxWidth: 150)
                    } else {
                        Text(address)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .frame(maxWidth: 150)
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.clear)
            )
            .foregroundStyle(.primary)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
        .frame(maxWidth: 160, alignment: .leading)
        .lineLimit(1)
    }
}
