import AppKit
import CoreImage
import Foundation

extension MinecraftSkinUtils {

    static func exportAvatarImage(type: SkinType, src: String, size: Int) async throws -> NSImage {
        let data: Data
        switch type {
        case .asset:
            guard let image = NSImage(named: src),
                  let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
                throw GlobalError.resource(
                    chineseMessage: "Asset 资源未找到: \(src)",
                    i18nKey: "error.resource.asset_not_found",
                    level: .silent
                )
            }
            let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
            guard let imageData = bitmapRep.representation(using: .png, properties: [:]) else {
                throw GlobalError.validation(
                    chineseMessage: "无效的图像数据",
                    i18nKey: "error.validation.invalid_image_data",
                    level: .silent
                )
            }
            data = imageData
        case .url:
            guard let url = URL(string: src) else {
                throw GlobalError.validation(
                    chineseMessage: "无效的URL: \(src)",
                    i18nKey: "error.validation.invalid_url",
                    level: .silent
                )
            }
            let request = URLRequest(url: url)
            let (responseData, httpResponse) = try await APIClient.performRequestWithResponse(request: request)

            guard httpResponse.statusCode == 200 else {
                throw GlobalError.download(
                    chineseMessage: "皮肤下载失败: HTTP \(httpResponse.statusCode)",
                    i18nKey: "error.download.skin_download_failed",
                    level: .silent
                )
            }
            data = responseData
        case .local:
            let fileURL = URL(fileURLWithPath: src)
            data = try Data(contentsOf: fileURL)
        }

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

        let headRect = CGRect(
            x: MinecraftSkinConstants.headStartX,
            y: ciImage.extent.height - MinecraftSkinConstants.headStartY - MinecraftSkinConstants.headHeight,
            width: MinecraftSkinConstants.headWidth,
            height: MinecraftSkinConstants.headHeight
        )
        let headCropped = ciImage.cropped(to: headRect)

        let layerRect = CGRect(
            x: MinecraftSkinConstants.layerStartX,
            y: ciImage.extent.height - MinecraftSkinConstants.layerStartY - MinecraftSkinConstants.layerHeight,
            width: MinecraftSkinConstants.layerWidth,
            height: MinecraftSkinConstants.layerHeight
        )
        let layerCropped = ciImage.cropped(to: layerRect)

        guard let headCGImage = ciContext.createCGImage(headCropped, from: headCropped.extent),
              let layerCGImage = ciContext.createCGImage(layerCropped, from: layerCropped.extent) else {
            throw GlobalError.validation(
                chineseMessage: "图像处理失败",
                i18nKey: "error.validation.image_processing_failed",
                level: .silent
            )
        }

        let hasLayerContent = hasNonTransparentPixels(layerCGImage)

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * size
        let bitsPerComponent = 8

        guard let context = CGContext(
            data: nil,
            width: size,
            height: size,
            bitsPerComponent: bitsPerComponent,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw GlobalError.validation(
                chineseMessage: "无法创建图像上下文",
                i18nKey: "error.validation.image_context_failed",
                level: .silent
            )
        }

        let headSize = hasLayerContent ? Int(Double(size) * 0.9) : size
        let headOffset = hasLayerContent ? (size - headSize) / 2 : 0
        context.interpolationQuality = .none
        context.draw(headCGImage, in: CGRect(x: headOffset, y: headOffset, width: headSize, height: headSize))

        if hasLayerContent {
            context.draw(layerCGImage, in: CGRect(x: 0, y: 0, width: size, height: size))
        }

        guard let finalCGImage = context.makeImage() else {
            throw GlobalError.validation(
                chineseMessage: "无法生成最终图像",
                i18nKey: "error.validation.final_image_failed",
                level: .silent
            )
        }

        return NSImage(cgImage: finalCGImage, size: NSSize(width: size, height: size))
    }
}
