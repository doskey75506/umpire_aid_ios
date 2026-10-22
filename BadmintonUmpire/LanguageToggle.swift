import SwiftUI

/// Globe button that toggles zh/en. Place in each screen's toolbar.
struct LanguageToggle: View {
    @ObservedObject private var lang = LanguageManager.shared

    var body: some View {
        Button {
            lang.toggle()
        } label: {
            Image(systemName: "globe")
        }
        .accessibilityLabel(lang.language == .zh ? "切换到英文" : "Switch to Chinese")
    }
}
