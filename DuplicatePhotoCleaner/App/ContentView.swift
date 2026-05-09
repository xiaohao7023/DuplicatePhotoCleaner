import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        if !appState.hasCompletedOnboarding {
            OnboardingView {
                withAnimation(.easeInOut(duration: 0.3)) { appState.hasCompletedOnboarding = true }
            }
        } else {
            DashboardView()
        }
    }
}
