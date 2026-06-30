//
//  CapeSelectionView.swift
//  PlayerFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation
import SwiftUI

/// Displays a single cape texture loaded from a URL.
struct CapeTextureView: View {
    let imageURL: String
    private var url: URL? { URL(string: imageURL.httpToHttps()) }

    var body: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .empty:
                ProgressView().controlSize(.mini)
            case let .success(image):
                capeImageContent(image: image)
            case .failure:
                Image(systemName: "photo")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
            @unknown default:
                Image(systemName: "photo")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
            }
        }
        .onDisappear {
            if let url {
                URLCache.shared.removeCachedResponse(
                    for: URLRequest(url: url),
                )
            }
        }
    }

    private func capeImageContent(image: Image) -> some View {
        GeometryReader { geometry in
            let containerWidth = geometry.size.width
            let containerHeight = geometry.size.height
            let capeAspectRatio: CGFloat = 10.0 / 16.0
            let containerAspectRatio = containerWidth / containerHeight

            let scale: CGFloat = containerAspectRatio > capeAspectRatio
                ? containerHeight / 16.0
                : containerWidth / 10.0

            let offsetX = (containerWidth - 10.0 * scale) / 2.0 - 1.0 * scale
            let offsetY = (containerHeight - 16.0 * scale) / 2.0 - 1.0 * scale

            image
                .resizable()
                .interpolation(.none)
                .frame(width: 64.0 * scale, height: 32.0 * scale)
                .offset(x: offsetX, y: offsetY)
                .clipped()
        }
    }

    private func capeImageContent(image: NSImage) -> some View {
        GeometryReader { geometry in
            let containerWidth = geometry.size.width
            let containerHeight = geometry.size.height
            let capeAspectRatio: CGFloat = 10.0 / 16.0
            let containerAspectRatio = containerWidth / containerHeight

            let scale: CGFloat = containerAspectRatio > capeAspectRatio
                ? containerHeight / 16.0
                : containerWidth / 10.0

            let offsetX = (containerWidth - 10.0 * scale) / 2.0 - 1.0 * scale
            let offsetY = (containerHeight - 16.0 * scale) / 2.0 - 1.0 * scale

            Image(nsImage: image)
                .resizable()
                .interpolation(.none)
                .frame(width: 64.0 * scale, height: 32.0 * scale)
                .offset(x: offsetX, y: offsetY)
                .clipped()
        }
    }
}

/// Displays a horizontally scrollable list of cape options for selection.
struct CapeSelectionView: View {
    let playerProfile: MinecraftProfileResponse?
    @Binding var selectedCapeId: String?
    @Binding var selectedCapeImageURL: String?
    @Binding var selectedCapeImage: NSImage?
    let onCapeSelected: (String?, String?) -> Void

    @StateObject private var viewModel: CapeSelectionViewModel

    init(
        playerProfile: MinecraftProfileResponse?,
        selectedCapeId: Binding<String?>,
        selectedCapeImageURL: Binding<String?>,
        selectedCapeImage: Binding<NSImage?>,
        onCapeSelected: @escaping (String?, String?) -> Void,
    ) {
        self.playerProfile = playerProfile
        _selectedCapeId = selectedCapeId
        _selectedCapeImageURL = selectedCapeImageURL
        _selectedCapeImage = selectedCapeImage
        self.onCapeSelected = onCapeSelected
        _viewModel = StateObject(
            wrappedValue: CapeSelectionViewModel(
                selectedCapeImageURL: selectedCapeImageURL,
                selectedCapeImage: selectedCapeImage,
            ),
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("skin.cape".localized()).font(.headline)

            if let playerProfile, let capes = playerProfile.capes, !capes.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        capeOption(id: nil, name: "skin.no_cape".localized(), isSystemOption: true)
                        ForEach(capes, id: \.id) { cape in
                            capeOption(id: cape.id, name: cape.alias ?? "skin.cape".localized(), imageURL: cape.url)
                        }
                    }.padding(4)
                }
            } else {
                Text("skin.no_capes_available".localized())
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .onDisappear {
            viewModel.cancel()
        }
    }

    private func capeOption(id: String?, name: String, imageURL: String? = nil, isSystemOption: Bool = false) -> some View {
        let isSelected = selectedCapeId == id

        return Button {
            guard !isSelected else { return }

            selectedCapeId = id
            viewModel.loadCapeImageIfNeeded(imageURL: imageURL)
            onCapeSelected(id, imageURL)
        } label: {
            VStack(spacing: 6) {
                capeIconContainer(isSelected: isSelected, imageURL: imageURL, isSystemOption: isSystemOption)
                Text(name)
                    .font(.caption)
                    .lineLimit(1)
                    .foregroundColor(isSelected ? .accentColor : .primary)
                    .frame(width: 42)
            }
        }
        .buttonStyle(.plain)
        .disabled(isSelected)
    }

    private func capeIconContainer(isSelected: Bool, imageURL: String?, isSystemOption: Bool) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.1))
                .frame(width: 50, height: 70)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(
                            isSelected ? Color.accentColor : Color.gray.opacity(0.3),
                            lineWidth: isSelected ? 2 : 1,
                        ),
                )

            if let imageURL {
                CapeTextureView(imageURL: imageURL)
                    .id(imageURL).frame(width: 42, height: 62).clipped().cornerRadius(6)
            } else if isSystemOption {
                Image(systemName: "xmark").font(.system(size: 16)).foregroundColor(.secondary)
            }
        }
    }
}
