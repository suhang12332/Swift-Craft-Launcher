import SwiftUI

struct FormSection<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
                .padding(.top, 6)
                .padding(.bottom, 6)
        }
    }
} 