import SwiftUI

// MARK: - Privacy Policy View
struct PrivacyPolicyView: View {
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
                            Image(systemName: "lock.shield.fill")
                                .font(.system(size: 50))
                                .foregroundColor(appAccentColor)

                            Text("Privacy Policy")
                                .font(.appLargeTitle)
                                .foregroundColor(.textPrimary)

                            Text("Last updated: January 2025")
                                .font(.appCaption)
                                .foregroundColor(.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 24)

                        // Content
                        privacyContent
                    }
                    .padding(AppDimensions.screenPadding)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Privacy Policy")
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

    private var privacyContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            PolicySection(title: "Introduction") {
                Text("Unforgotten (\"we\", \"our\", or \"us\") is committed to protecting your privacy. This Privacy Policy explains how we collect, use, disclose, and safeguard your information when you use our mobile application.")
            }

            PolicySection(title: "Information We Collect") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("We collect information that you provide directly to us, including:")

                    BulletPoint("Account information (email address, password)")
                    BulletPoint("Profile information (names, birthdays, photos)")
                    BulletPoint("Health-related information (medications, appointments)")
                    BulletPoint("Contact information for useful contacts")
                    BulletPoint("Mood tracking entries")
                    BulletPoint("Notes and reminders")
                }
            }

            PolicySection(title: "How We Use Your Information") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("We use the information we collect to:")

                    BulletPoint("Provide, maintain, and improve our services")
                    BulletPoint("Process transactions and send related information")
                    BulletPoint("Send you technical notices and support messages")
                    BulletPoint("Respond to your comments and questions")
                    BulletPoint("Enable family sharing features")
                    BulletPoint("Send medication and appointment reminders")
                }
            }

            PolicySection(title: "Data Storage and Security") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Your data is stored securely using industry-standard encryption and security measures. We use Supabase as our backend provider, which implements:")

                    BulletPoint("End-to-end encryption for data in transit")
                    BulletPoint("Encryption at rest for stored data")
                    BulletPoint("Row-level security policies")
                    BulletPoint("Regular security audits")
                }
            }

            PolicySection(title: "Data Sharing") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("We do not sell your personal information. We may share your information only in the following circumstances:")

                    BulletPoint("With family members you explicitly invite to share your account")
                    BulletPoint("With service providers who assist in our operations")
                    BulletPoint("To comply with legal obligations")
                    BulletPoint("To protect our rights and safety")
                }
            }

            PolicySection(title: "Your Rights") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("You have the right to:")

                    BulletPoint("Access your personal data")
                    BulletPoint("Correct inaccurate data")
                    BulletPoint("Delete your account and associated data")
                    BulletPoint("Export your data")
                    BulletPoint("Withdraw consent for optional processing")
                }
            }

            PolicySection(title: "Children's Privacy") {
                Text("Unforgotten is not intended for children under 13. We do not knowingly collect personal information from children under 13. If you believe we have collected such information, please contact us immediately.")
            }

            PolicySection(title: "Changes to This Policy") {
                Text("We may update this Privacy Policy from time to time. We will notify you of any changes by posting the new Privacy Policy on this page and updating the \"Last updated\" date.")
            }

            PolicySection(title: "Contact Us") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("If you have questions about this Privacy Policy, please contact us at:")

                    Link("support@unforgottenapp.com", destination: URL(string: "mailto:support@unforgottenapp.com")!)
                        .foregroundColor(appAccentColor)

                    Link("View full policy online", destination: URL(string: "https://unforgottenapp.com/privacy")!)
                        .font(.appCaption)
                        .foregroundColor(appAccentColor)
                        .padding(.top, 4)
                }
            }
        }
    }
}

// MARK: - Privacy Policy Panel Content
/// Panel version for iPad settings
struct PrivacyPolicyPanelContent: View {
    @Environment(\.appAccentColor) private var appAccentColor

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 40))
                        .foregroundColor(appAccentColor)

                    Text("Last updated: January 2025")
                        .font(.appCaption)
                        .foregroundColor(.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 16)

                // Content
                privacyContent
            }
            .padding(AppDimensions.screenPadding)
            .padding(.bottom, 40)
        }
        .background(Color.appBackground)
    }

    private var privacyContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            PolicySection(title: "Introduction") {
                Text("Unforgotten (\"we\", \"our\", or \"us\") is committed to protecting your privacy. This Privacy Policy explains how we collect, use, disclose, and safeguard your information when you use our mobile application.")
            }

            PolicySection(title: "Information We Collect") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("We collect information that you provide directly to us, including:")

                    BulletPoint("Account information (email address, password)")
                    BulletPoint("Profile information (names, birthdays, photos)")
                    BulletPoint("Health-related information (medications, appointments)")
                    BulletPoint("Contact information for useful contacts")
                    BulletPoint("Mood tracking entries")
                    BulletPoint("Notes and reminders")
                }
            }

            PolicySection(title: "How We Use Your Information") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("We use the information we collect to:")

                    BulletPoint("Provide, maintain, and improve our services")
                    BulletPoint("Process transactions and send related information")
                    BulletPoint("Send you technical notices and support messages")
                    BulletPoint("Respond to your comments and questions")
                    BulletPoint("Enable family sharing features")
                    BulletPoint("Send medication and appointment reminders")
                }
            }

            PolicySection(title: "Data Storage and Security") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Your data is stored securely using industry-standard encryption and security measures. We use Supabase as our backend provider, which implements:")

                    BulletPoint("End-to-end encryption for data in transit")
                    BulletPoint("Encryption at rest for stored data")
                    BulletPoint("Row-level security policies")
                    BulletPoint("Regular security audits")
                }
            }

            PolicySection(title: "Data Sharing") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("We do not sell your personal information. We may share your information only in the following circumstances:")

                    BulletPoint("With family members you explicitly invite to share your account")
                    BulletPoint("With service providers who assist in our operations")
                    BulletPoint("To comply with legal obligations")
                    BulletPoint("To protect our rights and safety")
                }
            }

            PolicySection(title: "Your Rights") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("You have the right to:")

                    BulletPoint("Access your personal data")
                    BulletPoint("Correct inaccurate data")
                    BulletPoint("Delete your account and associated data")
                    BulletPoint("Export your data")
                    BulletPoint("Withdraw consent for optional processing")
                }
            }

            PolicySection(title: "Children's Privacy") {
                Text("Unforgotten is not intended for children under 13. We do not knowingly collect personal information from children under 13. If you believe we have collected such information, please contact us immediately.")
            }

            PolicySection(title: "Changes to This Policy") {
                Text("We may update this Privacy Policy from time to time. We will notify you of any changes by posting the new Privacy Policy on this page and updating the \"Last updated\" date.")
            }

            PolicySection(title: "Contact Us") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("If you have questions about this Privacy Policy, please contact us at:")

                    Link("support@unforgottenapp.com", destination: URL(string: "mailto:support@unforgottenapp.com")!)
                        .foregroundColor(.accentYellow)

                    Link("View full policy online", destination: URL(string: "https://unforgottenapp.com/privacy")!)
                        .font(.appCaption)
                        .foregroundColor(.accentYellow)
                        .padding(.top, 4)
                }
            }
        }
    }
}

// MARK: - Policy Section
struct PolicySection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.appCardTitle)
                .foregroundColor(.textPrimary)

            content
                .font(.appBody)
                .foregroundColor(.textSecondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.cardBackground)
        .cornerRadius(AppDimensions.cardCornerRadius)
    }
}

// MARK: - Bullet Point
struct BulletPoint: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .foregroundColor(.textSecondary)
            Text(text)
                .foregroundColor(.textSecondary)
        }
    }
}

// MARK: - Preview
#Preview {
    PrivacyPolicyView()
}
