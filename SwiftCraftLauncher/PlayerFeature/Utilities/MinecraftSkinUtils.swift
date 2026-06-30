//
//  MinecraftSkinUtils.swift
//  PlayerFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import SwiftUI
import CoreImage
import Foundation
import AppKit

/// Renders a Minecraft player skin as a head avatar.
///
/// Supports loading from a remote URL, an asset catalog, or a local file path.
/// Rendered images are cached by source for efficient reuse.
struct MinecraftSkinUtils: View {
    let type: SkinType
    let src: String
    let size: CGFloat

    @State private var renderedCache: RenderedImageCache?
    @State private var error: String?
    @State private var isLoading: Bool = false
    @State private var loadTask: Task<Void, Never>?

    private var cacheKey: String {
        let typeString: String
        switch type {
        case .url:
            typeString = "url"
        case .asset:
            typeString = "asset"
        case .local:
            typeString = "local"
        }
        return "\(typeString):\(src)"
    }

    init(type: SkinType, src: String, size: CGFloat = 64) {
        self.type = type
        self.src = src
        self.size = size
    }

    var body: some View {
        ZStack {
            if let cache = renderedCache {
                avatarLayers(for: cache)
            } else if isLoading {
                VStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                }
            } else if error != nil {
                Self(type: .asset, src: "steve", size: size)
            }
        }
        .frame(width: size, height: size)
        .onAppear {
            if let cached = Self.getCachedRenderedImage(for: cacheKey) {
                self.renderedCache = cached
                self.isLoading = false
            } else {
                loadSkinData()
            }
        }
        .onChange(of: src) { _, _ in
            if let cached = Self.getCachedRenderedImage(for: cacheKey) {
                self.renderedCache = cached
                self.isLoading = false
                self.error = nil
            } else {
                self.renderedCache = nil
                self.error = nil
                loadSkinData()
            }
        }
        .onDisappear {
            loadTask?.cancel()
            loadTask = nil
        }
    }

    @ViewBuilder
    private func avatarLayers(for cache: RenderedImageCache) -> some View {
        ZStack {
            Image(decorative: cache.headImage, scale: 1.0)
                .interpolation(.none)
                .resizable()
                .frame(
                    width: cache.hasLayerContent ? size * 0.9 : size,
                    height: cache.hasLayerContent ? size * 0.9 : size
                )
                .clipped()
            if cache.hasLayerContent {
                Image(decorative: cache.layerImage, scale: 1.0)
                    .interpolation(.none)
                    .resizable()
                    .frame(width: size, height: size)
                    .clipped()
            }
        }
        .shadow(color: Color.black.opacity(0.6), radius: 1)
    }

    private func loadSkinData() {
        error = nil
        isLoading = true

        loadTask?.cancel()

        loadTask = Task {
            do {
                try Task.checkCancellation()

                Logger.shared.debug("Loading skin: \(src)")

                let data = try await loadData()

                try Task.checkCancellation()

                guard let ciImage = CIImage(data: data) else {
                    throw GlobalError.validation(
                        chineseMessage: "无效的图像数据",
                        i18nKey: "error.validation.invalid_image_data",
                        level: .silent
                    )
                }

                guard ciImage.extent.width == 64 && ciImage.extent.height == 64 else {
                    throw GlobalError.validation(
                        chineseMessage: "不支持的皮肤格式，仅支持64x64像素",
                        i18nKey: "error.validation.unsupported_skin_format",
                        level: .silent
                    )
                }

                try Task.checkCancellation()

                let cacheKeyValue = cacheKey
                let renderedCache = await Task.detached {
                    return await Self.renderAndCacheImage(ciImage, for: cacheKeyValue, context: Self.ciContext)
                }.value

                await MainActor.run {
                    self.renderedCache = renderedCache
                    self.isLoading = false
                }
            } catch is CancellationError {
                await MainActor.run {
                    self.isLoading = false
                }
                return
            } catch let urlError as URLError where urlError.code == .cancelled {
                await MainActor.run {
                    self.isLoading = false
                }
                return
            } catch {
                let globalError = GlobalError.from(error)
                await MainActor.run {
                    self.error = globalError.localizedDescription
                    self.isLoading = false
                }
                Logger.shared.error("❌ 皮肤加载失败: \(globalError.chineseMessage)")
                AppServices.errorHandler.handle(globalError)
            }
        }
    }
}
