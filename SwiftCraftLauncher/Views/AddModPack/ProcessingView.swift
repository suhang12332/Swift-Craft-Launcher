import SwiftUI

struct ProcessingView: View {
    var body: some View {
        VStack(spacing: 24) {
            ProgressView().controlSize(.small)

            Text("modpack.processing.title".localized())
                .font(.headline)
                .foregroundColor(.primary)

            Text("modpack.processing.subtitle".localized())
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .frame(maxWidth: .infinity, minHeight: 130)
        .padding()
    }
}
