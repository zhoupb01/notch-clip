// App/HotKeyManager.swift
import Carbon.HIToolbox

@MainActor
final class HotKeyManager {
    var onHotKey: (() -> Void)?
    // 仅在 register()（主线程）写入、在 deinit 读取一次；用 nonisolated(unsafe) 让 deinit 可访问
    private nonisolated(unsafe) var hotKeyRef: EventHotKeyRef?
    private nonisolated(unsafe) var handlerRef: EventHandlerRef?

    /// 注册 ⌘⇧V（v1 写死，不做自定义）
    func register() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                      eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, userData in
            guard let userData else { return noErr }
            let manager = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
            // Carbon 事件在主线程投递；跳回主 actor 调用回调
            DispatchQueue.main.async { MainActor.assumeIsolated { manager.onHotKey?() } }
            return noErr
        }, 1, &eventType, Unmanaged.passUnretained(self).toOpaque(), &handlerRef)

        let hotKeyID = EventHotKeyID(signature: OSType(0x4E43_4C50), id: 1)   // "NCLP"
        RegisterEventHotKey(UInt32(kVK_ANSI_V),
                            UInt32(cmdKey | shiftKey),
                            hotKeyID,
                            GetApplicationEventTarget(), 0, &hotKeyRef)
    }

    deinit {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        if let handlerRef { RemoveEventHandler(handlerRef) }
    }
}
