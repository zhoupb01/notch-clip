// UI/NotchRootView.swift
import SwiftUI

struct NotchRootView: View {
    @ObservedObject var vm: NotchViewModel
    @ObservedObject var store: HistoryStore
    let notchSize: CGSize
    var onPaste: (ClipItem) -> Void = { _ in }
    var onTogglePin: (ClipItem) -> Void = { _ in }

    private var bottomRadius: CGFloat {
        switch vm.state {
        case .idle: 10
        case .hud: 16
        case .panel: 18
        }
    }

    /// 03 第 3 节：展开用 spring，收回（回 idle）用 easeIn 0.18
    /// 展开弹簧适度过冲回弹，外壳「弹」开更灵动；底部圆角跟随同一动画一起过冲，出「液态」感
    private var stateAnimation: Animation {
        vm.state == .idle ? .easeIn(duration: 0.18)
                          : .spring(response: 0.42, dampingFraction: 0.66)
    }

    /// 内容级联入场：外壳先弹开，内容随后（延迟 0.06s）淡入 + 轻微下移放大归位，制造波浪/层次感。
    /// 退场仍必须 .identity 立即移除——退场视图参与布局会撑住 ZStack，收回时跳变（docs/03 第 3 节）
    private var contentTransition: AnyTransition {
        .asymmetric(
            insertion: .opacity
                .combined(with: .offset(y: 10))
                .combined(with: .scale(scale: 0.97, anchor: .top))
                .animation(.spring(response: 0.34, dampingFraction: 0.72).delay(0.06)),
            removal: .identity)
    }

    var body: some View {
        VStack(spacing: 0) {
            // 背景/裁剪挂在持久的 ZStack 上：三态切换时形状的 frame 才能插值出
            // 「从刘海长出来」的形变动画。switch 分支是不同视图身份，只能做 transition：
            // 进场淡入；退场立即移除（否则旧视图会撑住 ZStack 尺寸，收回时跳变）
            ZStack(alignment: .top) {
                Group {
                    switch vm.state {
                    case .idle:
                        Color.clear
                            .frame(width: notchSize.width, height: notchSize.height)
                    case .hud(let item):
                        HUDView(item: item, store: store, notchHeight: notchSize.height)
                            .frame(width: notchSize.width + 160)
                    case .panel:
                        PanelView(vm: vm, store: store, notchHeight: notchSize.height,
                                  onPaste: onPaste, onTogglePin: onTogglePin)
                            .frame(width: 420)
                            .frame(maxHeight: 480, alignment: .top)
                    }
                }
                .transition(contentTransition)
            }
            .background(Color.black)
            .clipShape(UnevenRoundedRectangle(cornerRadii: .init(bottomLeading: bottomRadius,
                                                                 bottomTrailing: bottomRadius)))
            .animation(stateAnimation, value: vm.state)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

struct IdleNotchView: View {
    let notchSize: CGSize

    var body: some View {
        VStack(spacing: 0) {
            UnevenRoundedRectangle(cornerRadii: .init(bottomLeading: 10, bottomTrailing: 10))
                .fill(Color.black)
                .frame(width: notchSize.width, height: notchSize.height)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}
