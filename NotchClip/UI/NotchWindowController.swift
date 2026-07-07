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

    /// 悬停唤醒开关。由 AppDelegate 按唤醒方式设置；关闭时刘海悬停不再展开面板
    var hoverWakeEnabled = true

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
        // 进入/退出全屏走 Space 切换（不触发 screenParameters）。若不重检测，刘海几何
        // 会相对当前模式变陈旧 → 面板位置/尺寸偏移、顶部与刘海衔接错位。切换时重建，
        // 让窗口位置、顶部安全区高按当前模式的刘海重新对齐
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                if self.viewModel.state != .idle { self.closePanel(restoreFocus: false) }
                self.rebuild()
            }
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
        case .idle, .hud:   // HUD 显示期间也接受悬停，直接升级为面板，消除复制后的失灵窗口
            guard hoverWakeEnabled else { hoverStart = nil; break }
            if notchHoverRect().contains(loc) {
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

    /// 空闲/HUD 态触发面板的悬停判定区（屏幕坐标）。
    /// 左右各放宽 20pt 降低盲瞄难度；上边越过屏幕顶 4pt——鼠标甩到顶边时 y 恰好
    /// 等于屏幕 maxY，而 NSRect.contains 上边界是半开区间会判失败
    private func notchHoverRect() -> NSRect {
        let n = geometry.notchRect
        return NSRect(x: n.minX - 20, y: n.minY, width: n.width + 40, height: n.height + 4)
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
            if event.keyCode == 53 {   // esc 关闭；列表操作全交给鼠标
                self.closePanel()
                return nil
            }
            return event   // 其余按键放行给搜索框
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
