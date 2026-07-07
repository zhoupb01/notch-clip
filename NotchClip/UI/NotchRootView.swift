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
    private var stateAnimation: Animation {
        vm.state == .idle ? .easeIn(duration: 0.18)
                          : .spring(response: 0.35, dampingFraction: 0.75)
    }

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch vm.state {
                case .idle:
                    Color.clear
                        .frame(width: notchSize.width, height: notchSize.height)
                case .hud(let item):
                    HUDView(item: item, store: store)
                        .frame(width: notchSize.width + 160, height: notchSize.height + 8)
                case .panel:
                    PanelView(vm: vm, store: store, notchHeight: notchSize.height,
                              onPaste: onPaste, onTogglePin: onTogglePin)
                        .frame(width: 420)
                        .frame(maxHeight: 480, alignment: .top)
                }
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
