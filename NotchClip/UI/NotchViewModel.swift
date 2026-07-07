// UI/NotchViewModel.swift
import AppKit
import Combine

@MainActor
final class NotchViewModel: ObservableObject {
    enum State: Equatable {
        case idle
        case hud(ClipItem)
        case panel
    }

    @Published private(set) var state: State = .idle
    @Published var searchText = ""
    @Published var selectedIndex = 0
    private(set) var panelOpenedByHover = false
    private var hudWork: DispatchWorkItem?

    func showHUD(_ item: ClipItem) {
        guard state != .panel else { return }   // 面板优先级高于 HUD（03 第 1 节）
        hudWork?.cancel()
        state = .hud(item)                       // 重复触发 = 刷新内容并重新计时
        let work = DispatchWorkItem { [weak self] in
            guard let self, case .hud = self.state else { return }
            self.state = .idle
        }
        hudWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2, execute: work)
    }

    func openPanel(byHover: Bool) {
        hudWork?.cancel()
        panelOpenedByHover = byHover
        searchText = ""
        selectedIndex = 0
        state = .panel
    }

    func closePanel() {
        guard state == .panel else { return }
        state = .idle
    }

    /// 面板展示列表：固定项在前，其余按时间倒序（store 本身就是倒序）；
    /// 搜索时隐藏图片条目；性能兜底最多 50 条。Controller 和 PanelView 都调用它，保证一致
    func displayItems(from all: [ClipItem]) -> [ClipItem] {
        var list = all
        let q = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        if !q.isEmpty {
            list = list.filter { item in
                guard item.type != .image else { return false }
                return (item.text ?? "").lowercased().contains(q)
            }
        }
        let pinned = list.filter { $0.isPinned }
        let normal = list.filter { !$0.isPinned }
        return Array((pinned + normal).prefix(50))
    }

    func moveSelection(_ delta: Int, itemCount: Int) {
        guard itemCount > 0 else { return }
        selectedIndex = min(max(selectedIndex + delta, 0), itemCount - 1)
    }
}
