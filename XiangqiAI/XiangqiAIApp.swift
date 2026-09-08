import SwiftUI

@main
struct XiangqiAIApp: App {
    @StateObject private var settings = AppSettings()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(settings)
        }
    }
}

final class AppSettings: ObservableObject {
    @AppStorage("engineThreads") var engineThreads = max(1, min(ProcessInfo.processInfo.activeProcessorCount, 8))
    @AppStorage("engineHashMB") var engineHashMB = 128
    @AppStorage("thinkTimeMs") var thinkTimeMs = 1500
    @AppStorage("aiPlaysRed") var aiPlaysRed = false
}

struct RootView: View {
    var body: some View {
        TabView {
            GameView()
                .tabItem { Label("对弈", systemImage: "gamecontroller") }
            AnalysisView()
                .tabItem { Label("分析", systemImage: "waveform.path.ecg") }
            SettingsView()
                .tabItem { Label("设置", systemImage: "gearshape") }
        }
    }
}
