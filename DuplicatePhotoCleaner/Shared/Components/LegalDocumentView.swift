import SwiftUI

enum LegalDocumentType {
    case privacyPolicy
    case termsOfUse

    var title: String {
        switch self {
        case .privacyPolicy: String(localized: "Privacy Policy")
        case .termsOfUse: String(localized: "Terms of Use")
        }
    }

    var url: URL? {
        switch self {
        case .privacyPolicy: URL(string: "https://xiaohao7023.github.io/dupes-legal/privacy.html")
        case .termsOfUse: URL(string: "https://xiaohao7023.github.io/dupes-legal/terms.html")
        }
    }
}

struct LegalDocumentView: View {
    let type: LegalDocumentType
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(type == .privacyPolicy ? LegalContent.privacyPolicy : LegalContent.termsOfUse)
                        .font(.appBodyRegular)
                        .foregroundStyle(Color.appTextPrimary)
                        .lineSpacing(4)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
            .background(Color.appBackground)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.appBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if let url = type.url {
                        Button {
                            UIApplication.shared.open(url)
                        } label: {
                            Image(systemName: "safari")
                                .font(.system(size: 15))
                                .foregroundStyle(Color.appPrimary)
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.appBody)
                        .foregroundStyle(Color.appPrimary)
                }
            }
        }
    }
}

// MARK: - Content

private enum LegalContent {

    static let privacyPolicy = """
    Privacy Policy

    Last updated: July 20, 2026

    In short: Your photos always stay on your device. We collect limited anonymous app-usage events to understand launches, onboarding, paywall views, and verified purchases.

    1. Information We Collect

    We do not collect your name, email address, precise location, photo content, or other user-generated content. The app sends limited anonymous usage events, app version, build number, storefront or device region, and a random installation identifier to our analytics service.

    The app accesses your photo library solely to perform local analysis (detecting duplicates, similar photos, blurry images, and screenshots). This access is handled through Apple's Photos framework and all processing occurs on-device.

    2. How Your Photos Are Used

    \u{2022} Your photos are analyzed locally on your device to identify duplicates, similar photos, blurry images, and screenshots.

    \u{2022} Photo analysis uses perceptual hashing, image quality assessment, and similarity detection \u{2014} all performed on-device using Apple's native frameworks.

    \u{2022} No photos, thumbnails, or image data are ever uploaded, transmitted, or stored externally.

    \u{2022} When you choose to delete photos, the deletion is performed through Apple's Photos framework. Deleted photos are moved to your device's "Recently Deleted" album where they can be recovered for up to 30 days.

    3. Data Storage

    The app stores the following data locally on your device using Apple's standard UserDefaults:

    \u{2022} App preferences (such as delete mode selection)

    \u{2022} Onboarding completion status

    \u{2022} Cumulative cleanup statistics (storage freed, items deleted)

    These preferences and cleanup statistics remain on your device. A separate random installation identifier is stored in Keychain so anonymous events can be counted without an account.

    4. In-App Purchases

    Duplicate Photo Cleaner offers a one-time lifetime purchase processed entirely through Apple's App Store and StoreKit framework. We do not have access to your payment information, which is handled securely by Apple.

    5. Third-Party Services

    The app uses our first-party analytics endpoint hosted on Cloudflare to process anonymous usage events. We do not use advertising SDKs, cross-app tracking, or sell personal data. Photos, thumbnails, filenames, and photo metadata are never included in analytics events.

    6. Children's Privacy

    The app does not knowingly collect personal information from children. Its limited analytics events are anonymous and are not used for advertising or tracking.

    7. Changes to This Policy

    We may update this Privacy Policy from time to time. Any changes will be reflected on this page with an updated "Last updated" date. We encourage you to review this policy periodically.

    8. Contact Us

    If you have any questions about this Privacy Policy, please contact us at: huangxiaohao7023@icloud.com
    """

    static let termsOfUse = """
    Terms of Use

    Last updated: May 12, 2026

    1. Acceptance of Terms

    By downloading, installing, or using Duplicate Photo Cleaner ("the App"), you agree to be bound by these Terms of Use. If you do not agree to these terms, please do not use the App.

    2. Description of Service

    Duplicate Photo Cleaner is a utility application that helps you manage your photo library by:

    \u{2022} Identifying duplicate photos

    \u{2022} Finding similar photos

    \u{2022} Detecting blurry or low-quality photos

    \u{2022} Organizing screenshots

    \u{2022} Managing video files

    All analysis is performed locally on your device. No photos or personal data are transmitted to external servers.

    3. License

    We grant you a non-exclusive, non-transferable, revocable license to use the App on any Apple-branded product that you own or control, in accordance with the Apple Media Services Terms and Conditions.

    4. In-App Purchase

    The App offers a one-time "Lifetime" purchase that permanently unlocks all photo cleanup features. This is a non-consumable purchase \u{2014} you pay once and own it forever.

    \u{2022} All payments are processed through Apple's App Store. We do not have access to your payment information.

    \u{2022} You may restore previous purchases at any time using the "Restore Purchase" button within the App.

    \u{2022} Prices may vary by region and are determined by Apple's App Store pricing tiers.

    \u{2022} Refund requests must be directed to Apple, as they are the payment processor.

    5. User Responsibilities

    You are responsible for:

    \u{2022} Reviewing photos before confirming deletion. Deleted photos are moved to your device's "Recently Deleted" album and can be recovered for up to 30 days.

    \u{2022} Ensuring you have adequate backups of important photos before performing bulk deletions.

    \u{2022} Using the App in compliance with all applicable laws and regulations.

    6. Disclaimer of Warranties

    The App is provided "as is" and "as available" without warranties of any kind, either express or implied. We do not warrant that:

    \u{2022} The App will be error-free or uninterrupted

    \u{2022} All duplicate or similar photos will be detected

    \u{2022} The App will be compatible with all devices or iOS versions

    7. Limitation of Liability

    To the maximum extent permitted by applicable law, we shall not be liable for any indirect, incidental, special, consequential, or punitive damages, including but not limited to loss of data, photos, or profits, arising from your use of the App.

    While the App provides tools to help you manage your photo library, you acknowledge that photo deletion is an irreversible action after the 30-day recovery period in "Recently Deleted." We strongly recommend reviewing your selections carefully before confirming any deletion.

    8. Intellectual Property

    The App, including its design, code, and content, is the intellectual property of the developer and is protected by applicable copyright and intellectual property laws. You may not copy, modify, distribute, or reverse-engineer the App.

    9. Changes to Terms

    We reserve the right to modify these Terms of Use at any time. Changes will be posted on this page with an updated "Last updated" date. Continued use of the App after changes constitutes acceptance of the revised terms.

    10. Contact

    For questions about these Terms of Use, please contact us at: huangxiaohao7023@icloud.com
    """
}
