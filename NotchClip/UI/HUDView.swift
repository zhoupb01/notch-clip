// UI/HUDView.swift
import SwiftUI

struct HUDView: View {
    let item: ClipItem
    let store: HistoryStore
    let notchHeight: CGFloat

    var body: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: notchHeight)   // 顶部安全区：避免内容被硬件刘海遮住
            HStack(spacing: 10) {
                leadingIcon
                Text(primaryText)
                    .font(item.type == .color ? .system(size: 12, design: .monospaced)
                                              : .system(size: 12))
                    .foregroundStyle(.white.opacity(0.92))
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 8)
                Text(trailingLabel)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.45))
                    .fixedSize()
            }
            .padding(.horizontal, 16)
            .frame(height: 28)
        }
    }

    @ViewBuilder private var leadingIcon: some View {
        switch item.type {
        case .color:
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(nsColor: NSColor(hexString: item.text ?? "") ?? .white))
                .frame(width: 14, height: 14)
        case .image:
            if let url = store.imageURL(for: item), let img = ThumbnailCache.shared.thumbnail(for: url) {
                Image(nsImage: img)
                    .resizable().scaledToFill()
                    .frame(width: 18, height: 18)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            } else {
                Image(systemName: "photo")
                    .font(.system(size: 15)).foregroundStyle(.white.opacity(0.8))
            }
        default:
            Image(systemName: iconName)
                .font(.system(size: 15)).foregroundStyle(.white.opacity(0.8))
        }
    }

    private var iconName: String {
        switch item.type {
        case .text: "doc.on.doc"
        case .link: "link"
        case .file: "doc"
        case .color: "paintpalette"
        case .image: "photo"
        }
    }

    private var primaryText: String {
        switch item.type {
        case .text:
            let oneLine = (item.text ?? "").replacingOccurrences(of: "\n", with: " ")
            return String(oneLine.prefix(40))
        case .link:
            let t = item.text ?? ""
            if let r = t.range(of: "://") { return String(t[r.upperBound...]) }
            return t
        case .color:
            return item.text ?? ""
        case .image:
            if let url = store.imageURL(for: item), let size = ThumbnailCache.pixelSize(of: url) {
                return "图片 \(size.width)×\(size.height)"
            }
            return "图片"
        case .file:
            return (item.text as NSString?)?.lastPathComponent ?? "文件"
        }
    }

    private var trailingLabel: String {
        let name: String = switch item.type {
        case .text: "文本"
        case .link: "链接"
        case .color: "颜色"
        case .image: "图片"
        case .file: "文件"
        }
        return "已复制 · " + name
    }
}

extension NSColor {
    /// 解析 #RGB / #RRGGBB / #RRGGBBAA
    convenience init?(hexString: String) {
        var s = hexString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard s.hasPrefix("#") else { return nil }
        s.removeFirst()
        if s.count == 3 { s = s.map { "\($0)\($0)" }.joined() }
        if s.count == 6 { s += "FF" }
        guard s.count == 8, let v = UInt64(s, radix: 16) else { return nil }
        self.init(srgbRed: CGFloat((v >> 24) & 0xFF) / 255,
                  green:   CGFloat((v >> 16) & 0xFF) / 255,
                  blue:    CGFloat((v >> 8) & 0xFF) / 255,
                  alpha:   CGFloat(v & 0xFF) / 255)
    }
}
