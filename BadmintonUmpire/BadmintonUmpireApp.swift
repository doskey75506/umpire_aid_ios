import SwiftUI
import ScoringCore

@main
struct BadmintonUmpireApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = HistoryStore()

    var body: some Scene {
        WindowGroup {
            Group {
                if let screen = SmokeScreen.current {
                    SmokeView(screen: screen)
                } else {
                    RootView()
                }
            }
            .environmentObject(store)
            .environmentObject(LanguageManager.shared)
        }
    }
}

struct RootView: View {
    @ObservedObject private var lang = LanguageManager.shared

    var body: some View {
        NavigationStack {
            List {
                NavigationLink {
                    SetupView()
                } label: {
                    Label(lang.t("nav.start"), systemImage: "play.circle")
                }
                NavigationLink {
                    HistoryView()
                } label: {
                    Label(lang.t("nav.history"), systemImage: "clock.arrow.circlepath")
                }
            }
            .navigationTitle(lang.t("app.title"))
            .toolbar {
                LanguageToggle()
            }
        }
    }
}
