// UI/ThumbnailCache.swift
import AppKit
import ImageIO

/// 缩略图缓存：ImageIO 解码阶段直接降采样，内存里只留小图。
/// 不能用 NSImage(contentsOf:) 整图解码——一张 Retina 截图解码后几十 MB，
/// 配合 NSCache 无上限缓存会把常驻内存顶到 GB 级
@MainActor
final class ThumbnailCache {
    static let shared = ThumbnailCache()
    private let cache = NSCache<NSURL, NSImage>()

    /// maxPixel = 48（24pt@2x），已覆盖面板 24pt 与 HUD 18pt 的显示尺寸
    func thumbnail(for url: URL, maxPixel: Int = 48) -> NSImage? {
        if let hit = cache.object(forKey: url as NSURL) { return hit }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
        ]
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil),
              let cg = CGImageSourceCreateThumbnailAtIndex(src, 0, options as CFDictionary)
        else { return nil }
        let img = NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height))
        cache.setObject(img, forKey: url as NSURL)
        return img
    }

    /// 只读文件头取原图像素尺寸，不解码位图（HUD 的「图片 W×H」用）
    nonisolated static func pixelSize(of url: URL) -> (width: Int, height: Int)? {
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any],
              let w = props[kCGImagePropertyPixelWidth] as? Int,
              let h = props[kCGImagePropertyPixelHeight] as? Int
        else { return nil }
        return (w, h)
    }
}
