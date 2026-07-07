// UI/NotchWindowController.swift
import AppKit
import SwiftUI
import Combine

@MainActor
final class NotchWindowController {
    static let containerSize = NSSize(width: 640, height: 520)

    let viewModel: NotchViewModel
    private let store: HistoryStore
    private let pasteService: PasteService
    private let monitor: ClipboardMonitor

    private(set) var geometry = NotchGeometry.detect()
    private var panel: NotchPanel?
    private var cancellables = Set<AnyCancellable>()
    private var hoverTimer: Timer?
    private var hoverStart: Date?
    private var outsideStart: Date?
    private var keyMonitor: Any?
    private var mouseDownMonitor: Any?

    init(viewModel: NotchViewModel, store: HistoryStore,
         pasteService: PasteService, monitor: ClipboardMonitor) {
        self.viewModel = viewModel
        self.store = store
        self.pasteService = pasteService
        self.monitor = monitor
        buildWindow()
        bindState()
        startHoverTimer()
        installEventMonitors()
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.rebuild() }
        }
    }

    // MARK: 对外动作

    func openPanel(byHover: Bool) {
        guard viewModel.state != .panel else { return }
        pasteService.rememberFrontmostApp()   // 必须在展开之前记录（决策 D4）
        viewModel.openPanel(byHover: byHover)
        if !byHover {
            // 非激活面板拿 key：能接收打字，但不激活本应用、不夺走前台身份
            panel?.makeKeyAndOrderFront(nil)
        }
    }

    func closePanel(restoreFocus: Bool = true) {
        guard viewModel.state == .panel else { return }
        viewModel.closePanel()
        if restoreFocus { pasteService.restoreFocus() }
    }

    /// 粘贴。顺序不能变：先把状态切回 idle（面板收起），再走 PasteService
    func paste(_ item: ClipItem) {
        viewModel.closePanel()
        pasteService.paste(item, imagesDir: store.imagesDir, monitor: monitor)
    }

    private func pasteSelected() {
        let items = viewModel.displayItems(from: store.items)
        guard items.indices.contains(viewModel.selectedIndex) else { return }
        paste(items[viewModel.selectedIndex])
    }

    private func paste(at index: Int) {
        let items = viewModel.displayItems(from: store.items)
        guard items.indices.contains(index) else { return }
        paste(items[index])
    }

    // MARK: 窗口

    private func containerRect() -> NSRect {
        let s = Self.containerSize
        return NSRect(x: geometry.notchRect.midX - s.width / 2,
                      y: geometry.notchRect.maxY - s.height,
                      width: s.width, height: s.height)
    }

    private func buildWindow() {
        let p = NotchPanel(contentRect: containerRect())
        let root = NotchRootView(vm: viewModel, store: store,
                                 notchSize: geometry.notchRect.size,
                                 onPaste: { [weak self] in self?.paste($0) },
                                 onTogglePin: { [weak self] in self?.store.togglePin($0) })
        p.contentView = NSHostingView(rootView: root)
        p.ignoresMouseEvents = true
        p.orderFrontRegardless()
        panel = p
    }

    private func rebuild() {
        panel?.orderOut(nil)
        panel = nil
        geometry = NotchGeometry.detect()
        buildWindow()
    }

    private func bindState() {
        viewModel.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.panel?.ignoresMouseEvents = (state != .panel)
            }
            .store(in: &cancellables)
    }

    // MARK: 悬停检测（决策 D3：0.1s 轮询鼠标位置，不依赖窗口事件、无需权限）

    private func startHoverTimer() {
        let t = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.hoverTick() }
        }
        RunLoop.main.add(t, forMode: .common)
        hoverTimer = t
    }

    private func hoverTick() {
        let loc = NSEvent.mouseLocation
        switch viewModel.state {
        case .idle:
            if geometry.notchRect.contains(loc) {
                if hoverStart == nil { hoverStart = Date() }
                if Date().timeIntervalSince(hoverStart!) >= 0.15 {   // 悬停 0.15s 触发
                    hoverStart = nil
                    openPanel(byHover: true)
                }
            } else {
                hoverStart = nil
            }
        case .panel where viewModel.panelOpenedByHover:
            if panelHoverRect().contains(loc) {
                outsideStart = nil
            } else {
                if outsideStart == nil { outsideStart = Date() }
                if Date().timeIntervalSince(outsideStart!) >= 0.4 {  // 移出 0.4s 自动关
                    outsideStart = nil
                    closePanel()
                }
            }
        default:
            hoverStart = nil
            outsideStart = nil
        }
    }

    /// 面板悬停判定区域（屏幕坐标），按最大面板尺寸计算，四周放宽 8pt
    private func panelHoverRect() -> NSRect {
        NSRect(x: geometry.notchRect.midX - 210,
               y: geometry.notchRect.maxY - 480,
               width: 420, height: 480).insetBy(dx: -8, dy: -8)
    }

    // MARK: 事件监听

    private func installEventMonitors() {
        // 本地键盘监听：面板打开且本应用是按键接收方时生效。
        // 处理过的按键返回 nil 吞掉；其他按键返回 event 放行给搜索框
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.viewModel.state == .panel else { return event }
            let itemCount = self.viewModel.displayItems(from: self.store.items).count
            switch event.keyCode {
            case 53:      self.closePanel(); return nil                                    // esc
            case 36, 76:  self.pasteSelected(); return nil                                 // ↩ / enter
            case 125:     self.viewModel.moveSelection(1, itemCount: itemCount); return nil  // ↓
            case 126:     self.viewModel.moveSelection(-1, itemCount: itemCount); return nil // ↑
            default: break
            }
            if event.modifierFlags.contains(.command),
               let ch = event.charactersIgnoringModifiers,
               let n = Int(ch), (1...9).contains(n) {
                self.paste(at: n - 1)                                                      // ⌘1~9
                return nil
            }
            return event
        }
        // 全局鼠标按下：点击面板外 → 关闭。全局监听收不到本应用内部的点击，
        // 所以面板内的点击天然不会误触发
        mouseDownMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.viewModel.state == .panel else { return }
                if !self.panelHoverRect().contains(NSEvent.mouseLocation) {
                    self.closePanel(restoreFocus: false)   // 用户点了别处，别再抢焦点
                }
            }
        }
    }
}
