import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    var body: some View {
        NavigationStack {
            Form {
                Section("Pikafish") {
                    Stepper("搜索线程：\(settings.engineThreads)", value: $settings.engineThreads, in: 1...max(1, min(ProcessInfo.processInfo.activeProcessorCount, 16)))
                    Picker("置换表 Hash", selection: $settings.engineHashMB) {
                        ForEach([32, 64, 128, 256, 512], id: \.self) { Text("\($0) MB").tag($0) }
                    }
                    Picker("AI 思考时间", selection: $settings.thinkTimeMs) {
                        Text("0.5 秒").tag(500); Text("1.5 秒").tag(1500); Text("3 秒").tag(3000); Text("5 秒").tag(5000); Text("10 秒").tag(10000)
                    }
                }
                Section("对弈") { Toggle("AI 执红方（新游戏后生效）", isOn: $settings.aiPlaysRed) }
                Section("离线与许可") {
                    Text("Pikafish 和 pikafish.nnue 随 App Bundle 一起提供。引擎搜索仅使用 iPad 本地 CPU 与线程；不使用浏览器、WebView、WebAssembly 或远程服务。")
                    Text("Pikafish 以 GPLv3 发布。分发本 App 时必须同时遵守资源目录内的许可证与源码提供义务。")
                }
            }.navigationTitle("设置")
        }
    }
}
