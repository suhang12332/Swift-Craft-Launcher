import SwiftUI
import CoreImage
import Foundation
import AppKit

enum SkinType {
    case url, asset, local
}

class RenderedImageCache: NSObject {
    let headImage: CGImage
    let layerImage: CGImage
    let hasLayerContent: Bool
    let cost: Int

    init(headImage: CGImage, layerImage: CGImage, hasLayerContent: Bool) {
        self.headImage = headImage
        self.layerImage = layerImage
        self.hasLayerContent = hasLayerContent
        let headCost = Int(headImage.width * headImage.height * 4)
        let layerCost = Int(layerImage.width * layerImage.height * 4)
        self.cost = headCost + layerCost + 2 * 1024
        super.init()
    }
}

enum MinecraftSkinConstants {
    static let padding: CGFloat = 6
    static let networkTimeout: TimeInterval = 10.0
    static let maxCacheSize = 100
    static let maxCacheMemory = 2 * 1024 * 1024

    static let headStartX: CGFloat = 8
    static let headStartY: CGFloat = 8
    static let headWidth: CGFloat = 8
    static let headHeight: CGFloat = 8

    static let layerStartX: CGFloat = 40
    static let layerStartY: CGFloat = 8
    static let layerWidth: CGFloat = 8
    static let layerHeight: CGFloat = 8
}
