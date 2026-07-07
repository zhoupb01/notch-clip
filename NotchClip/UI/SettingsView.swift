// UI/SettingsView.swift
import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @State private var maxItems = Settings.shared.maxItems
    @State private var excluded = Settings.shared.excludedBundleIDs.sorted().joined(separator: "\n")
    @State private var launchAtLogin = (SMAppService.mainApp.status == .enabled)

    var body: some View {
        Form {
            Picker("历史条数上限", selection: $maxItems) {
                Text("100").tag(100)
                Text("500").tag(500)
                Text("1000").tag(1000)
            }
            .onChange(of: maxItems) { Settings.shared.maxItems = maxItems }

            Toggle("开机自动启动", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) {
                    if launchAtLogin { try? SMAppService.mainApp.register() }
                    else { try? SMAppService.mainApp.unregister() }
                }

            Section("排除的应用（每行一个 Bundle ID，例如 com.apple.Terminal）") {
                TextEditor(text: $excluded)
                    .font(.system(size: 12, design: .monospaced))
                    .frame(height: 120)
                    .onChange(of: excluded) {
                        let ids = excluded.split(separator: "\n")
                            .map { $0.trimmingCharacters(in: .whitespaces) }
                            .filter { !$0.isEmpty }
                        Settings.shared.excludedBundleIDs = Set(ids)
                    }
            }
        }
        .formStyle(.grouped)
        .frame(width: 420, height: 320)
    }
}
