import SwiftUI

public struct PlayerSettingsView: View {
    public init() {}
    public var body: some View {
        HStack {
            Spacer()
            Form {
                Section(header: Text("settings.player.title".localized())) {
                    Text("settings.player.placeholder".localized())
                }
            }
//            .frame(maxWidth: 500)
            Spacer()
        }
        .padding()
    }
} 
