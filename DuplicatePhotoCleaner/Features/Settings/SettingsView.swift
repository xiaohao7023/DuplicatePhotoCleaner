import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @State private var showDeletePreference = false
    @State private var showingPrivacy = false
    @State private var showingTerms = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if appState.isPurchased {
                        HStack {
                            Image(systemName: "crown.fill").font(.system(size: 15)).foregroundStyle(Color.appSuccess)
                                .frame(width: 32, height: 32)
                                .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.appSuccess.opacity(0.1)))
                            Text("Lifetime Member").font(.appBody).foregroundStyle(Color.appTextPrimary)
                            Spacer()
                            Text("Active").font(.appCaption).foregroundStyle(Color.appSuccess)
                        }
                    } else {
                        Button {
                            // 直接拉起终身买断购买
                            Task {
                                let ok = await StoreKitManager.shared.purchaseLifetimeDirect()
                                if ok {
                                    appState.purchasedProductIDs = StoreKitManager.shared.purchasedProductIDs
                                }
                            }
                        } label: {
                            HStack {
                                Image(systemName: "crown.fill").font(.system(size: 15)).foregroundStyle(Color.appPrimary)
                                    .frame(width: 32, height: 32)
                                    .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.appPrimary.opacity(0.1)))
                                Text("Upgrade to Premium").font(.appBody).foregroundStyle(Color.appPrimary)
                                Spacer()
                                Image(systemName: "chevron.right").font(.system(size: 14, weight: .semibold)).foregroundStyle(Color.appTextQuaternary)
                            }
                        }.buttonStyle(.plain)
                    }
                } header: {
                    Text("Membership").font(.appSmallSemibold).foregroundStyle(Color.appTextSecondary)
                        .textCase(.uppercase).tracking(0.6)
                }

                Section {
                    Button { showDeletePreference = true } label: {
                        HStack {
                            Image(systemName: "trash").font(.system(size: 15)).foregroundStyle(Color.appDanger)
                                .frame(width: 32, height: 32)
                                .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.appDanger.opacity(0.1)))
                            Text("Delete Mode").font(.appBody).foregroundStyle(Color.appTextPrimary)
                            Spacer()
                            Text(appState.deletePreference.label)
                                .font(.appCaption).foregroundStyle(Color.appTextTertiary)
                            Image(systemName: "chevron.right").font(.system(size: 14, weight: .semibold)).foregroundStyle(Color.appTextQuaternary)
                        }
                    }.buttonStyle(.plain)
                } header: {
                    Text("Delete").font(.appSmallSemibold).foregroundStyle(Color.appTextSecondary)
                        .textCase(.uppercase).tracking(0.6)
                }

                Section {
                    Button { showingPrivacy = true } label: {
                        SettingsNavRow(icon: "lock.shield.fill", iconColor: .appSuccess, title: "Privacy Policy")
                    }.buttonStyle(.plain)

                    Button { showingTerms = true } label: {
                        SettingsNavRow(icon: "doc.text.fill", iconColor: .appTeal, title: "Terms of Use")
                    }.buttonStyle(.plain)

                    Button {
                        if let url = URL(string: "mailto:huangxiaohao7023@icloud.com") { UIApplication.shared.open(url) }
                    } label: {
                        SettingsNavRow(icon: "envelope.fill", iconColor: .appPurple, title: "Contact Us")
                    }.buttonStyle(.plain)

                    HStack {
                        Image(systemName: "info.circle.fill").font(.system(size: 15)).foregroundStyle(Color.appSlateBlue)
                            .frame(width: 32, height: 32)
                            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.appSlateBlue.opacity(0.1)))
                        Text("Version").font(.appBody).foregroundStyle(Color.appTextPrimary)
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")
                            .font(.appCaption).foregroundStyle(Color.appTextTertiary)
                    }
                } header: {
                    Text("About").font(.appSmallSemibold).foregroundStyle(Color.appTextSecondary)
                        .textCase(.uppercase).tracking(0.6)
                }

                Section {
                    HStack(spacing: 12) {
                        Image(systemName: "lock.shield.fill").font(.system(size: 24)).foregroundStyle(Color.appSuccess)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("100% Private").font(.appSmallSemibold).foregroundStyle(Color.appTextPrimary)
                            Text("All photo analysis happens on your device. Nothing is uploaded.")
                                .font(.appCaption).foregroundStyle(Color.appTextSecondary)
                        }
                    }.padding(.vertical, 4)
                }

                #if DEBUG
                Section {
                    Button {
                        appState.hasCompletedOnboarding = false
                    } label: {
                        HStack {
                            Image(systemName: "arrow.uturn.backward.circle").font(.system(size: 15)).foregroundStyle(Color.appPrimary)
                                .frame(width: 32, height: 32)
                                .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.appPrimary.opacity(0.1)))
                            Text("Replay Onboarding").font(.appBody).foregroundStyle(Color.appTextPrimary)
                            Spacer()
                        }
                    }.buttonStyle(.plain)

                    Button {
                        appState.resetFreeQuota()
                    } label: {
                        HStack {
                            Image(systemName: "arrow.counterclockwise").font(.system(size: 15)).foregroundStyle(Color.appTeal)
                                .frame(width: 32, height: 32)
                                .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.appTeal.opacity(0.1)))
                            Text("Reset Free Quota").font(.appBody).foregroundStyle(Color.appTextPrimary)
                            Spacer()
                            Text("\(appState.freeDeletesUsedBytes / (1024*1024))MB / 100MB")
                                .font(.appCaption).foregroundStyle(Color.appTextTertiary)
                        }
                    }.buttonStyle(.plain)

                    if appState.isPurchased {
                        Button {
                            appState.resetPurchaseState()
                        } label: {
                            HStack {
                                Image(systemName: "person.crop.circle.badge.xmark").font(.system(size: 15)).foregroundStyle(Color.appDanger)
                                    .frame(width: 32, height: 32)
                                    .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.appDanger.opacity(0.1)))
                                Text("Reset Purchase").font(.appBody).foregroundStyle(Color.appDanger)
                                Spacer()
                            }
                        }.buttonStyle(.plain)
                    }
                } header: {
                    Text("Debug").font(.appSmallSemibold).foregroundStyle(Color.appTextTertiary)
                        .textCase(.uppercase).tracking(0.6)
                }
                #endif
            }
            .listStyle(.insetGrouped)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }.font(.appBody).foregroundStyle(Color.appPrimary)
                }
            }
            .sheet(isPresented: $showDeletePreference) {
                DeletePreferencePickerView()
                    .environment(appState)
            }
            .sheet(isPresented: $showingPrivacy) {
                LegalDocumentView(type: .privacyPolicy)
            }
            .sheet(isPresented: $showingTerms) {
                LegalDocumentView(type: .termsOfUse)
            }
        }
    }
}

private struct SettingsNavRow: View {
    let icon: String; let iconColor: Color; let title: String
    var body: some View {
        HStack {
            Image(systemName: icon).font(.system(size: 15)).foregroundStyle(iconColor)
                .frame(width: 32, height: 32)
                .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(iconColor.opacity(0.1)))
            Text(title).font(.appBody).foregroundStyle(Color.appTextPrimary)
            Spacer()
            Image(systemName: "chevron.right").font(.system(size: 14, weight: .semibold)).foregroundStyle(Color.appTextQuaternary)
        }
    }
}

private struct SettingsToggleRow: View {
    let icon: String; let iconColor: Color; let title: String; @Binding var isOn: Bool
    var body: some View {
        HStack {
            Image(systemName: icon).font(.system(size: 15)).foregroundStyle(iconColor)
                .frame(width: 32, height: 32)
                .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(iconColor.opacity(0.1)))
            Text(title).font(.appBody).foregroundStyle(Color.appTextPrimary)
            Spacer()
            Toggle("", isOn: $isOn).tint(Color.appPrimary)
        }
    }
}
