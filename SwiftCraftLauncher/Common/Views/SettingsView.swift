import SwiftUI
import Foundation

/// 通用设置视图
/// 用于显示应用程序的设置选项
public struct SettingsView: View {
    @ObservedObject private var general = GeneralSettingsManager.shared
    
    
    /// 计算最大允许的内存分配 (MB)
    private var maximumMemoryAllocation: Int {
        let physicalMemoryBytes = ProcessInfo.processInfo.physicalMemory
        let physicalMemoryMB = physicalMemoryBytes / 1048576 // 将字节转换为 MB
        // 计算总内存的 70%，并确保至少为 512MB
        let calculatedMax = Int(Double(physicalMemoryMB) * 0.7)
        // 确保最大值也是 512 的倍数
        let roundedMax = (calculatedMax / 512) * 512
        return max(roundedMax, 512)
    }
    
    public init() {}
    
    public var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("settings.general.tab".localized(), systemImage: "gearshape")
                }
            PlayerSettingsView()
                .tabItem {
                    Label("settings.player.tab".localized(), systemImage: "person.crop.circle")
                }
            GameSettingsView()
                .tabItem {
                    Label("settings.game.tab".localized(), systemImage: "gamecontroller")
                }
//            AcknowledgementsView()
//                .tabItem {
//                    Label("settings.acknowledgements.tab".localized(), systemImage: "star.bubble")
//                }
        }
        .padding(.vertical, 24)
        .frame(maxWidth: 840)
        .preferredColorScheme(general.themeMode.colorScheme)
    }
}

#Preview {
    SettingsView()
} 



