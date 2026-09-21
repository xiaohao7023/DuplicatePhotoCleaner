import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var appState
    @State private var permissionManager = PhotoPermissionManager()
    @State private var hasRequestedPermission = false
    @State private var permissionStatus: PhotoPermissionStatus?

    var body: some View {
        Group {
            if appState.hasCompletedOnboarding && !hasRequestedPermission {
                // 老用户：直接进首页（扫一遍库拿数据），先确认权限
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Preparing your private scan...")
                        .font(.appCaption)
                        .foregroundStyle(Color.appTextSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.appBackground)
                .onAppear {
                    requestPermission()
                }
            } else {
                // 唯一主页：未完成 onboarding 时先放 3 页介绍，之后原地变成首页
                OnboardingView()
            }
        }
    }

    private func requestPermission() {
        Task {
            let status = await permissionManager.requestPermission()
            permissionStatus = status
            hasRequestedPermission = true
        }
    }
}
