import SwiftUI

struct DescriptionTextWithPopover: View {
    private static let hoverDelayNanoseconds: UInt64 = 500_000_000

    let description: String
    @State private var showPopover = false
    @State private var hoverTask: Task<Void, Never>?

    var body: some View {
        Button {
            showPopover.toggle()
        } label: {
            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            if hovering {
                schedulePopover()
            } else {
                cancelHoverTask()
                showPopover = false
            }
        }
        .popover(isPresented: $showPopover, arrowEdge: .top) {
            VStack(alignment: .leading) {
                Text(description)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineLimit(nil)
                    .multilineTextAlignment(.leading)
            }
            .padding()
            .frame(maxWidth: 500)
            .fixedSize(horizontal: true, vertical: false)
        }
        .onDisappear {
            cancelHoverTask()
            showPopover = false
        }
    }

    private func schedulePopover() {
        cancelHoverTask()
        hoverTask = Task {
            try? await Task.sleep(nanoseconds: Self.hoverDelayNanoseconds)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                showPopover = true
            }
        }
    }

    private func cancelHoverTask() {
        hoverTask?.cancel()
        hoverTask = nil
    }
}
