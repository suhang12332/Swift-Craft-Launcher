import SwiftUI
import AppKit
import Combine

struct MacOSGameCenterView: View {
    @State private var currentPage = 0
    let timer = Timer.publish(every: 3, on: .main, in: .common).autoconnect()
    
    var body: some View {
        GeometryReader { rootGeo in
            // 基于窗口尺寸计算 heroHeight
            let heroHeight: CGFloat = rootGeo.size.height * 0.5
            // 额外的顶部与列表间隔（近似值，若需要更精确可调整）
            let topBarSpace: CGFloat = 64
            let continueListTopPadding: CGFloat = 200
            let calculatedBackgroundHeight = topBarSpace + heroHeight + 20 + continueListTopPadding
            // 限制背景高度为 16:9，避免过度向下延伸
            let max16by9Height = rootGeo.size.width * 9.0 / 16.0
            let backgroundHeight = min(calculatedBackgroundHeight, max16by9Height)

            ZStack(alignment: .top) {
                // 背景：水平延展但垂直受限为 backgroundHeight
                BackgroundContainer(currentPage: currentPage)
                    .frame(height: backgroundHeight)
                    .ignoresSafeArea(edges: .horizontal)

                    // 可滚动的内容位于背景之上
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 0) {
                            // 游戏详情介绍（去掉多余的顶间距，以便内容能滑动到 topbar 之下）
                            HeroInfoView(currentPage: $currentPage, timer: timer, heroHeight: heroHeight)
                                .padding(.leading, 60)

                            // 底部“继续游戏”列表
                            ContinuePlayingListNeo()
                                .padding(.top, 200)
                                .padding(.bottom, 50)
                        }
                        .frame(maxWidth: .infinity)
                    }

                    // 顶部工具栏作为最上层 overlay，不改变滚动布局
                    CustomTopBar()
                        .padding(.top, 10)
                        .zIndex(2)
            }
        }
        .frame(minWidth: 900, minHeight: 600)
    }
}

// MARK: - 背景组件
struct BackgroundContainer: View {
    let currentPage: Int
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                // 根据当前页面改变背景渐变
                let gradientColors: [Color] = {
                    switch currentPage {
                    case 0: return [Color(nsColor: .darkGray), Color.orange.opacity(0.3)]
                    case 1: return [Color(nsColor: .darkGray), Color.yellow.opacity(0.3)]
                    case 2: return [Color(nsColor: .darkGray), Color.blue.opacity(0.3)]
                    default: return [Color(nsColor: .darkGray), .black]
                    }
                }()
                
                Rectangle()
                    .fill(LinearGradient(colors: gradientColors, startPoint: .top, endPoint: .bottom))
                
                // 根据当前页面改变光晕颜色
                let glowColor: Color = {
                    switch currentPage {
                    case 0: return .orange
                    case 1: return .yellow
                    case 2: return .blue
                    default: return .orange
                    }
                }()
                
                // 模拟左侧的橙色光晕
                Circle()
                    .fill(glowColor.opacity(0.4))
                    .blur(radius: 100)
                    .frame(width: 600, height: 600)
                    .offset(x: -geo.size.width/3, y: -100)
                
                // 底部轻量遮罩，避免遮挡整个背景，使背景能延展到继续游戏区域
                LinearGradient(
                    gradient: Gradient(colors: [.clear, .black.opacity(0.18)]),
                    startPoint: UnitPoint(x: 0.5, y: 0.6),
                    endPoint: .bottom
                )
            }
        }
        // 移除 ignoresSafeArea，让背景只在页面区域显示
    }
}

// MARK: - 顶部导航栏 (macOS 风格)
struct CustomTopBar: View {
    var body: some View {
        HStack {
            Spacer()
            
            // 中央控制台
            HStack(spacing: 25) {
                NavBarItem(title: "主页", isActive: true)
                NavBarItem(title: "Arcade")
                NavBarItem(title: "朋友")
                NavBarItem(title: "资料库")
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14, weight: .bold))
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 20)
            // 使用更浅的模糊材质并降低不透明度，避免出现明显的黑色遮挡
            .background(VisualEffectView(material: .popover, blendingMode: .withinWindow)
                            .clipShape(Capsule())
                            .opacity(0.75))
            .overlay(Capsule().stroke(Color.white.opacity(0.06), lineWidth: 0.5))
            
            Spacer()
            
            // 用户头像
            Image(systemName: "person.crop.circle.fill")
                .resizable()
                .frame(width: 30, height: 30)
                .padding(.trailing, 20)
        }
        .foregroundColor(.white)
    }
}

struct NavBarItem: View {
    let title: String
    var isActive: Bool = false
    
    var body: some View {
        Text(title)
            .font(.system(size: 13, weight: isActive ? .bold : .medium))
            .opacity(isActive ? 1.0 : 0.6)
            .onTapGesture { /* 点击逻辑 */ }
    }
}

// MARK: - 英雄展示区
struct HeroInfoView: View {
    @Binding var currentPage: Int
    let timer: Publishers.Autoconnect<Timer.TimerPublisher>
    let heroHeight: CGFloat

    var body: some View {
        GeometryReader { geo in
            let pageWidth = min(900, geo.size.width - 120)

            VStack {
                // 卡片式英雄区：带圆角与阴影
                ZStack {
                    // 横向轮播 + 控制（把箭头和指示器也放到 proxy 范围内，方便调用 scrollTo）
                    ScrollViewReader { proxy in
                        VStack(spacing: 0) {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 0) {
                                    // 页面 1
                                    ZStack(alignment: .leading) {
                                    VStack(alignment: .leading, spacing: 15) {
                                        HStack {
                                            Image(systemName: "flame.fill")
                                                .foregroundColor(.orange)
                                            Text("元气骑士 · 挑战")
                                        }
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.white.opacity(0.9))

                                        Text("最快通关时间")
                                            .font(.system(size: 48, weight: .heavy))
                                            .foregroundColor(.white)

                                        Text("👥 2 到 16 位玩家")
                                            .font(.system(size: 14))
                                            .foregroundColor(.white.opacity(0.7))

                                        Button(action: {}) {
                                            Text("开始挑战")
                                                .font(.system(size: 15, weight: .bold))
                                                .foregroundColor(.white)
                                                .padding(.vertical, 10)
                                                .padding(.horizontal, 40)
                                                .background(Capsule().fill(Color.white.opacity(0.2)))
                                        }
                                        .buttonStyle(.plain)
                                        .contentShape(Capsule())
                                        .onHover { inside in
                                            if inside { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                                        }
                                    }
                                    .padding(.leading, 36)
                                    .padding(.top, 28)
                                }
                                .frame(width: pageWidth, height: heroHeight)
                                .id(0)

                                // 页面 2
                                ZStack(alignment: .leading) {
                                    VStack(alignment: .leading, spacing: 15) {
                                        HStack {
                                            Image(systemName: "star.fill")
                                                .foregroundColor(.yellow)
                                            Text("冒险岛 · 探索")
                                        }
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.white.opacity(0.9))

                                        Text("最高探索等级")
                                            .font(.system(size: 48, weight: .heavy))
                                            .foregroundColor(.white)

                                        Text("🌍 1 到 8 位玩家")
                                            .font(.system(size: 14))
                                            .foregroundColor(.white.opacity(0.7))

                                        Button(action: {}) {
                                            Text("开始探索")
                                                .font(.system(size: 15, weight: .bold))
                                                .foregroundColor(.white)
                                                .padding(.vertical, 10)
                                                .padding(.horizontal, 40)
                                                .background(Capsule().fill(Color.white.opacity(0.2)))
                                        }
                                        .buttonStyle(.plain)
                                        .contentShape(Capsule())
                                        .onHover { inside in
                                            if inside { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                                        }
                                    }
                                    .padding(.leading, 36)
                                    .padding(.top, 28)
                                }
                                .frame(width: pageWidth, height: heroHeight)
                                .id(1)

                                // 页面 3
                                ZStack(alignment: .leading) {
                                    VStack(alignment: .leading, spacing: 15) {
                                        HStack {
                                            Image(systemName: "bolt.fill")
                                                .foregroundColor(.blue)
                                            Text("速度竞技 · 竞速")
                                        }
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.white.opacity(0.9))

                                        Text("最快圈速记录")
                                            .font(.system(size: 48, weight: .heavy))
                                            .foregroundColor(.white)

                                        Text("🏎️ 1 到 4 位玩家")
                                            .font(.system(size: 14))
                                            .foregroundColor(.white.opacity(0.7))

                                        Button(action: {}) {
                                            Text("开始竞速")
                                                .font(.system(size: 15, weight: .bold))
                                                .foregroundColor(.white)
                                                .padding(.vertical, 10)
                                                .padding(.horizontal, 40)
                                                .background(Capsule().fill(Color.white.opacity(0.2)))
                                        }
                                        .buttonStyle(.plain)
                                        .contentShape(Capsule())
                                        .onHover { inside in
                                            if inside { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                                        }
                                    }
                                    .padding(.leading, 36)
                                    .padding(.top, 28)
                                }
                                .frame(width: pageWidth, height: heroHeight)
                                .id(2)
                                }
                            }
                            .frame(height: heroHeight)
                            .overlay(alignment: .center) {
                                HStack {
                                    Button(action: {
                                        withAnimation {
                                            currentPage = (currentPage - 1 + 3) % 3
                                            proxy.scrollTo(currentPage, anchor: .center)
                                        }
                                    }) {
                                        Circle()
                                            .fill(Color.black.opacity(0.25))
                                            .frame(width: 44, height: 44)
                                            .overlay(Image(systemName: "chevron.left").foregroundColor(.white))
                                    }
                                    .buttonStyle(.plain)

                                    Spacer()

                                    Button(action: {
                                        withAnimation {
                                            currentPage = (currentPage + 1) % 3
                                            proxy.scrollTo(currentPage, anchor: .center)
                                        }
                                    }) {
                                        Circle()
                                            .fill(Color.black.opacity(0.25))
                                            .frame(width: 44, height: 44)
                                            .overlay(Image(systemName: "chevron.right").foregroundColor(.white))
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.horizontal, 18)
                                .frame(height: heroHeight)
                            }
                            .onReceive(timer) { _ in
                                withAnimation {
                                    currentPage = (currentPage + 1) % 3
                                    proxy.scrollTo(currentPage, anchor: .center)
                                }
                            }

                            // 指示器（可点击跳转）
                            VStack {
                                Spacer()
                                HStack(spacing: 10) {
                                    ForEach(0..<3) { i in
                                        Circle()
                                            .fill(i == currentPage ? Color.white : Color.white.opacity(0.35))
                                            .frame(width: i == currentPage ? 10 : 6, height: i == currentPage ? 10 : 6)
                                            .animation(.easeInOut, value: currentPage)
                                            .onTapGesture {
                                                withAnimation {
                                                    currentPage = i
                                                    proxy.scrollTo(i, anchor: .center)
                                                }
                                            }
                                    }
                                }
                                .padding(.bottom, 18)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .shadow(color: Color.black.opacity(0.45), radius: 20, x: 0, y: 8)
                .padding(.horizontal, 24)

                // 底部留白（图标行上方）
                Spacer().frame(height: 18)
            }
            .frame(width: geo.size.width)
        }
        .frame(height: heroHeight)
    }
}

// MARK: - 底部横向列表
struct ContinuePlayingListNeo: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("继续游戏")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
                .padding(.leading, 60)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 18) {
                    ForEach(0..<12) { index in
                        GameIconViewNeo(gameName: "Game \(index + 1)", iconName: "gamecontroller.fill")
                    }
                }
                .padding(.horizontal, 60)
                .padding(.vertical, 12)
            }
        }
    }
}

// MARK: - GameIconView
struct GameIconViewNeo: View {
    let gameName: String
    let iconName: String
    @State private var isHovered = false
    
    var body: some View {
        VStack {
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.gray.opacity(0.2))
                .frame(width: 85, height: 85)
                .overlay(
                    Image(systemName: iconName)
                        .font(.largeTitle)
                        .foregroundColor(.white.opacity(0.3))
                )
        }
        .scaleEffect(isHovered ? 1.05 : 1.0)
        .animation(.spring(response: 0.3), value: isHovered)
        .onHover { isHovered = $0 } 
    }
}

struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
#Preview {
    MacOSGameCenterView()
}
