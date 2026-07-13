// UI/PanelView.swift
import SwiftUI

struct PanelView: View {
    @ObservedObject var vm: NotchViewModel
    @ObservedObject var store: HistoryStore
    let notchHeight: CGFloat
    var onPaste: (ClipItem) -> Void
    var onTogglePin: (ClipItem) -> Void

    @FocusState private var searchFocused: Bool

    var body: some View {
        let items = vm.displayItems(from: store.items)
        VStack(spacing: 0) {
            Color.clear.frame(height: notchHeight)   // 顶部安全区：避开硬件刘海

            // 搜索行
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.45))
                TextField("搜索剪贴板历史", text: $vm.searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.92))
                    .focused($searchFocused)
            }
            .padding(.horizontal, 12)
            .frame(height: 34)

            divider

            // 列表（固定项已由 displayItems 排到最前）
            if items.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                            PanelRow(item: item,
                                     isSelected: index == vm.selectedIndex,
                                     thumbnailURL: store.imageURL(for: item))
                                .contentShape(Rectangle())
                                .onTapGesture { onPaste(item) }
                                .onHover { hovering in
                                    if hovering { vm.selectedIndex = index }
                                }
                                .contextMenu {
                                    Button(item.isPinned ? "取消固定" : "固定") { onTogglePin(item) }
                                    Button("删除") { store.delete(item) }
                                }
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                }
            }

            divider

            // 底部提示条
            HStack(spacing: 16) {
                Text("点击粘贴")
                Text("右键固定 / 删除")
            }
            .font(.system(size: 11))
            .foregroundStyle(.white.opacity(0.35))
            .frame(height: 26)
        }
        .background(Color.black)   // 纯黑，与刘海容器/HUD 一致，尽量贴近物理刘海的真黑
        .onAppear {
            // ⌘⇧V 呼出才聚焦搜索；悬停呼出不聚焦（03 第 4 节）
            if !vm.panelOpenedByHover { searchFocused = true }
        }
        .onChange(of: vm.searchText) { vm.selectedIndex = 0 }
    }

    private var divider: some View {
        Rectangle().fill(.white.opacity(0.12)).frame(height: 0.5)
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            if vm.searchText.isEmpty {
                Text("还没有剪贴板记录")
                    .font(.system(size: 12)).foregroundStyle(.white.opacity(0.6))
                Text("复制任何内容，它会出现在这里")
                    .font(.system(size: 11)).foregroundStyle(.white.opacity(0.35))
            } else {
                Text("没有匹配的记录")
                    .font(.system(size: 12)).foregroundStyle(.white.opacity(0.6))
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 120)
    }
}

private struct PanelRow: View {
    let item: ClipItem
    let isSelected: Bool
    let thumbnailURL: URL?

    var body: some View {
        HStack(spacing: 10) {
            leadingIcon
            Text(primaryText)
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.9))
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 8)
            Text(sourceAndTime)
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.4))
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .frame(height: 36)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.white.opacity(0.09) : Color.clear)
        )
    }

    @ViewBuilder private var leadingIcon: some View {
        if item.isPinned {
            Image(systemName: "pin.fill")
                .font(.system(size: 12))
                .foregroundStyle(Color(red: 250/255, green: 199/255, blue: 117/255)) // #FAC775
        } else {
            switch item.type {
            case .color:
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(nsColor: NSColor(hexString: item.text ?? "") ?? .white))
                    .frame(width: 14, height: 14)
            case .image:
                if let url = thumbnailURL, let img = ThumbnailCache.shared.thumbnail(for: url) {
                    Image(nsImage: img).resizable().scaledToFill()
                        .frame(width: 24, height: 24)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                } else {
                    Image(systemName: "photo").font(.system(size: 13)).foregroundStyle(.white.opacity(0.7))
                }
            case .text:
                Image(systemName: "doc.on.doc").font(.system(size: 13)).foregroundStyle(.white.opacity(0.7))
            case .link:
                Image(systemName: "link").font(.system(size: 13)).foregroundStyle(.white.opacity(0.7))
            case .file:
                Image(systemName: "doc").font(.system(size: 13)).foregroundStyle(.white.opacity(0.7))
            }
        }
    }

    private var primaryText: String {
        switch item.type {
        case .image: "图片"
        case .file: (item.text as NSString?)?.lastPathComponent ?? "文件"
        default: (item.text ?? "").replacingOccurrences(of: "\n", with: " ")
        }
    }

    private var sourceAndTime: String {
        let app = item.sourceAppName ?? "未知"
        return "\(app) · \(relativeTimeString(item.createdAt))"
    }
}

/// 相对时间：刚刚 / N 分钟前 / N 小时前 / M月d日（03 第 4 节）
func relativeTimeString(_ date: Date) -> String {
    let s = Date().timeIntervalSince(date)
    if s < 60 { return "刚刚" }
    if s < 3600 { return "\(Int(s / 60)) 分钟前" }
    if s < 86400 { return "\(Int(s / 3600)) 小时前" }
    let f = DateFormatter()
    f.dateFormat = "M月d日"
    return f.string(from: date)
}
