import SwiftUI

// MARK: - Terms of Service View
struct TermsOfServiceView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.appAccentColor) private var appAccentColor

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Header
                        VStack(spacing: 12) {
                            Image(systemName: "doc.text.fill")
                                .font(.system(size: 50))
                                .foregroundColor(appAccentColor)

                            Text("Terms of Service")
                                .font(.appLargeTitle)
                                .foregroundColor(.textPrimary)

                            Text("Last updated: January 2025")
                                .font(.appCaption)
                                .foregroundColor(.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 24)

                        // Content
                        termsContent
                    }
                    .padding(AppDimensions.screenPadding)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Terms of Service")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(appAccentColor)
                }
            }
        }
    }

    private var termsContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            PolicySection(title: "Agreement to Terms") {
                Text("By accessing or using Unforgotten, you agree to be bound by these Terms of Service. If you do not agree to these terms, please do not use our application.")
            }

            PolicySection(title: "Description of Service") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Unforgotten is a mobile application designed to help users manage information about loved ones with memory conditions. Our services include:")

                    BulletPoint("Profile management for family members and contacts")
                    BulletPoint("Medication tracking and reminders")
                    BulletPoint("Appointment scheduling and notifications")
                    BulletPoint("Birthday and important date tracking")
                    BulletPoint("Mood tracking and history")
                    BulletPoint("Family sharing and collaboration features")
                }
            }

            PolicySection(title: "User Accounts") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("To use Unforgotten, you must create an account. You agree to:")

                    BulletPoint("Provide accurate and complete information")
                    BulletPoint("Maintain the security of your password")
                    BulletPoint("Notify us immediately of any unauthorized access")
                    BulletPoint("Accept responsibility for all activities under your account")
                }
            }

            PolicySection(title: "Acceptable Use") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("You agree not to:")

                    BulletPoint("Use the service for any unlawful purpose")
                    BulletPoint("Upload malicious code or harmful content")
                    BulletPoint("Attempt to gain unauthorized access to our systems")
                    BulletPoint("Interfere with other users' access to the service")
                    BulletPoint("Collect personal information about other users without consent")
                    BulletPoint("Use the service to store or transmit infringing content")
                }
            }

            PolicySection(title: "Premium Subscriptions") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Unforgotten offers premium subscription plans with additional features:")

                    BulletPoint("Subscriptions automatically renew unless cancelled")
                    BulletPoint("You may cancel at any time through your App Store settings")
                    BulletPoint("Refunds are handled according to Apple's refund policies")
                    BulletPoint("We reserve the right to change subscription pricing with notice")
                }
            }

            PolicySection(title: "Health Information Disclaimer") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Important: Unforgotten is a personal organization tool, not a medical device.")

                    BulletPoint("Information stored should not replace professional medical advice")
                    BulletPoint("Always consult healthcare providers for medical decisions")
                    BulletPoint("Medication reminders are aids, not substitutes for proper medical care")
                    BulletPoint("We are not responsible for any medical decisions based on app data")
                }
            }

            PolicySection(title: "Family Sharing") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("When you invite family members to share your account:")

                    BulletPoint("You control who has access and their permission level")
                    BulletPoint("You are responsible for the actions of invited members")
                    BulletPoint("Shared information may be viewed by all account members")
                    BulletPoint("You can revoke access at any time")
                }
            }

            PolicySection(title: "Intellectual Property") {
                Text("Unforgotten and its original content, features, and functionality are owned by us and are protected by international copyright, trademark, and other intellectual property laws. You retain ownership of any content you create within the app.")
            }

            PolicySection(title: "Limitation of Liability") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("To the maximum extent permitted by law:")

                    BulletPoint("We provide the service \"as is\" without warranties")
                    BulletPoint("We are not liable for any indirect or consequential damages")
                    BulletPoint("Our total liability is limited to amounts paid by you")
                    BulletPoint("We do not guarantee uninterrupted or error-free service")
                }
            }

            PolicySection(title: "Termination") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("We may terminate or suspend your account if you:")

                    BulletPoint("Violate these Terms of Service")
                    BulletPoint("Engage in fraudulent or illegal activities")
                    BulletPoint("Fail to pay applicable subscription fees")

                    Text("Upon termination, your right to use the service will cease immediately. You may request export of your data before account deletion.")
                        .padding(.top, 8)
                }
            }

            PolicySection(title: "Changes to Terms") {
                Text("We reserve the right to modify these terms at any time. We will notify you of significant changes through the app or via email. Continued use of the service after changes constitutes acceptance of the new terms.")
            }

            PolicySection(title: "Governing Law") {
                Text("These terms shall be governed by and construed in accordance with applicable laws, without regard to conflict of law principles.")
            }

            PolicySection(title: "Contact Us") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("If you have questions about these Terms of Service, please contact us at:")

                    Link("support@unforgottenapp.com", destination: URL(string: "mailto:support@unforgottenapp.com")!)
                        .foregroundColor(appAccentColor)

                    Link("View full terms online", destination: URL(string: "https://unforgottenapp.com/terms")!)
                        .font(.appCaption)
                        .foregroundColor(appAccentColor)
                        .padding(.top, 4)
                }
            }
        }
    }
}

// MARK: - Terms of Service Panel Content
/// Panel version for iPad settings
struct TermsOfServicePanelContent: View {
    @Environment(\.appAccentColor) private var appAccentColor

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 40))
                        .foregroundColor(appAccentColor)

                    Text("Last updated: January 2025")
                        .font(.appCaption)
                        .foregroundColor(.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 16)

                // Content
                termsContent
            }
            .padding(AppDimensions.screenPadding)
            .padding(.bottom, 40)
        }
        .background(Color.appBackground)
    }

    private var termsContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            PolicySection(title: "Agreement to Terms") {
                Text("By accessing or using Unforgotten, you agree to be bound by these Terms of Service. If you do not agree to these terms, please do not use our application.")
            }

            PolicySection(title: "Description of Service") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Unforgotten is a mobile application designed to help users manage information about loved ones with memory conditions. Our services include:")

                    BulletPoint("Profile management for family members and contacts")
                    BulletPoint("Medication tracking and reminders")
                    BulletPoint("Appointment scheduling and notifications")
                    BulletPoint("Birthday and important date tracking")
                    BulletPoint("Mood tracking and history")
                    BulletPoint("Family sharing and collaboration features")
                }
            }

            PolicySection(title: "User Accounts") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("To use Unforgotten, you must create an account. You agree to:")

                    BulletPoint("Provide accurate and complete information")
                    BulletPoint("Maintain the security of your password")
                    BulletPoint("Notify us immediately of any unauthorized access")
                    BulletPoint("Accept responsibility for all activities under your account")
                }
            }

            PolicySection(title: "Acceptable Use") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("You agree not to:")

                    BulletPoint("Use the service for any unlawful purpose")
                    BulletPoint("Upload malicious code or harmful content")
                    BulletPoint("Attempt to gain unauthorized access to our systems")
                    BulletPoint("Interfere with other users' access to the service")
                    BulletPoint("Collect personal information about other users without consent")
                    BulletPoint("Use the service to store or transmit infringing content")
                }
            }

            PolicySection(title: "Premium Subscriptions") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Unforgotten offers premium subscription plans with additional features:")

                    BulletPoint("Subscriptions automatically renew unless cancelled")
                    BulletPoint("You may cancel at any time through your App Store settings")
                    BulletPoint("Refunds are handled according to Apple's refund policies")
                    BulletPoint("We reserve the right to change subscription pricing with notice")
                }
            }

            PolicySection(title: "Health Information Disclaimer") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Important: Unforgotten is a personal organization tool, not a medical device.")

                    BulletPoint("Information stored should not replace professional medical advice")
                    BulletPoint("Always consult healthcare providers for medical decisions")
                    BulletPoint("Medication reminders are aids, not substitutes for proper medical care")
                    BulletPoint("We are not responsible for any medical decisions based on app data")
                }
            }

            PolicySection(title: "Family Sharing") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("When you invite family members to share your account:")

                    BulletPoint("You control who has access and their permission level")
                    BulletPoint("You are responsible for the actions of invited members")
                    BulletPoint("Shared information may be viewed by all account members")
                    BulletPoint("You can revoke access at any time")
                }
            }

            PolicySection(title: "Intellectual Property") {
                Text("Unforgotten and its original content, features, and functionality are owned by us and are protected by international copyright, trademark, and other intellectual property laws. You retain ownership of any content you create within the app.")
            }

            PolicySection(title: "Limitation of Liability") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("To the maximum extent permitted by law:")

                    BulletPoint("We provide the service \"as is\" without warranties")
                    BulletPoint("We are not liable for any indirect or consequential damages")
                    BulletPoint("Our total liability is limited to amounts paid by you")
                    BulletPoint("We do not guarantee uninterrupted or error-free service")
                }
            }

            PolicySection(title: "Termination") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("We may terminate or suspend your account if you:")

                    BulletPoint("Violate these Terms of Service")
                    BulletPoint("Engage in fraudulent or illegal activities")
                    BulletPoint("Fail to pay applicable subscription fees")

                    Text("Upon termination, your right to use the service will cease immediately. You may request export of your data before account deletion.")
                        .padding(.top, 8)
                }
            }

            PolicySection(title: "Changes to Terms") {
                Text("We reserve the right to modify these terms at any time. We will notify you of significant changes through the app or via email. Continued use of the service after changes constitutes acceptance of the new terms.")
            }

            PolicySection(title: "Governing Law") {
                Text("These terms shall be governed by and construed in accordance with applicable laws, without regard to conflict of law principles.")
            }

            PolicySection(title: "Contact Us") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("If you have questions about these Terms of Service, please contact us at:")

                    Link("support@unforgottenapp.com", destination: URL(string: "mailto:support@unforgottenapp.com")!)
                        .foregroundColor(.accentYellow)

                    Link("View full terms online", destination: URL(string: "https://unforgottenapp.com/terms")!)
                        .font(.appCaption)
                        .foregroundColor(.accentYellow)
                        .padding(.top, 4)
                }
            }
        }
    }
}

// MARK: - Preview
#Preview {
    TermsOfServiceView()
}
