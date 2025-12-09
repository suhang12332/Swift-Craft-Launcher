//
//  OnboardingView.swift
//  SwiftCraftLauncher
//
//  Created by Auto on 2025/1/28.
//

import SwiftUI

/// Onboarding 交互器
struct OnboardingInteractor {
    var didSelectGetStarted: () -> Void
}

/// Onboarding 幻灯片数据模型
struct OnboardingSlide: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let imageName: String?
    let systemImage: String?

    init(
        title: String,
        description: String,
        imageName: String? = nil,
        systemImage: String? = nil
    ) {
        self.title = title
        self.description = description
        self.imageName = imageName
        self.systemImage = systemImage
    }
}

/// Onboarding 视图
/// 用于引导用户了解应用的主要功能
struct OnboardingView: View {
    let interactor: OnboardingInteractor
    let slides: [OnboardingSlide]

    @State private var currentPage = 0
    @State private var dragOffset: CGFloat = 0

    init(
        interactor: OnboardingInteractor,
        slides: [OnboardingSlide] = []
    ) {
        self.interactor = interactor
        self.slides = slides.isEmpty ? Self.defaultSlides : slides
    }
    
    var body: some View {
        ZStack {
            // 背景
            Color(NSColor.windowBackgroundColor)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // 跳过按钮
                HStack {
                    Spacer()
                    Button("onboarding.skip") {
                        interactor.didSelectGetStarted()
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                }

                // 幻灯片内容
                TabView(selection: $currentPage) {
                    ForEach(Array(slides.enumerated()), id: \.element.id) { index, slide in
                        OnboardingSlideView(slide: slide)
                            .tag(index)
                    }
                }
                .frame(maxHeight: .infinity)

                // 底部按钮
                VStack(spacing: 16) {
                    // 页面指示器
                    HStack(spacing: 8) {
                        ForEach(0..<slides.count, id: \.self) { index in
                            Circle()
                                .fill(index == currentPage ? Color.accentColor : Color.secondary.opacity(0.3))
                                .frame(width: 8, height: 8)
                                .animation(.spring(response: 0.3), value: currentPage)
                        }
                    }
                    .padding(.bottom, 8)
                    
                    // 操作按钮
                    HStack(spacing: 12) {
                        if currentPage > 0 {
                            Button("onboarding.previous") {
                                withAnimation {
                                    currentPage -= 1
                                }
                            }
                            .buttonStyle(.bordered)
                        }

                        Spacer()

                        if currentPage < slides.count - 1 {
                            Button("onboarding.next") {
                                withAnimation {
                                    currentPage += 1
                                }
                            }
                            .buttonStyle(.borderedProminent)
                        } else {
                            Button("onboarding.get_started") {
                                interactor.didSelectGetStarted()
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                        }
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, 32)
                }
            }
        }
        .frame(width: 600, height: 500)
    }

    // MARK: - Default Slides
    static var defaultSlides: [OnboardingSlide] {
        [
            OnboardingSlide(
                title: "onboarding.welcome.title",
                description: "onboarding.welcome.description",
                systemImage: "gamecontroller.fill"
            ),
            OnboardingSlide(
                title: "onboarding.features.title",
                description: "onboarding.features.description",
                systemImage: "sparkles"
            ),
            OnboardingSlide(
                title: "onboarding.ready.title",
                description: "onboarding.ready.description",
                systemImage: "checkmark.circle.fill"
            ),
        ]
    }
}

// MARK: - Onboarding Slide View
private struct OnboardingSlideView: View {
    let slide: OnboardingSlide

    var body: some View {
        VStack(spacing: 24) {
            // 图片/图标
            if let systemImage = slide.systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 80))
                    .foregroundColor(.accentColor)
                    .padding(.bottom, 16)
            } else if let imageName = slide.imageName {
                Image(imageName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 200, maxHeight: 200)
                    .padding(.bottom, 16)
            }

            // 标题
            Text(slide.title)
                .font(.system(size: 32, weight: .bold))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            // 描述
            Text(slide.description)
                .font(.system(size: 16))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 48)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 40)
    }
}

#Preview {
    OnboardingView(
        interactor: OnboardingInteractor(didSelectGetStarted: {})
    )
}

