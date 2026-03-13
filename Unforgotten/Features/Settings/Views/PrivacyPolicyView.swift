import SwiftUI

// MARK: - Privacy Policy View
struct PrivacyPolicyView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.sidePanelDismiss) private var sidePanelDismiss
    @Environment(\.appAccentColor) private var appAccentColor
    @Environment(UserPreferences.self) private var userPreferences
    @Environment(UserHeaderOverrides.self) private var headerOverrides
    @Environment(HeaderStyleManager.self) private var headerStyleManager

    /// Computed effective accent color (respects hasCustomAccentColor flag)
    private var effectiveAccentColor: Color {
        if userPreferences.hasCustomAccentColor {
            return userPreferences.accentColor
        } else {
            return headerStyleManager.defaultAccentColor
        }
    }

    @State private var isCheckmarkPressed = false

    /// Dismisses the view using side panel dismiss if available, otherwise standard dismiss
    private func dismissView() {
        if let sidePanelDismiss {
            sidePanelDismiss()
        } else {
            dismiss()
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Custom header with Done button
            HStack {
                    HStack(spacing: 12) {
                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: 18))
                            .foregroundColor(effectiveAccentColor)
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(effectiveAccentColor.opacity(0.15))
                            )

                        Text("Privacy Policy")
                            .font(.appTitle)
                            .foregroundColor(.textPrimary)
                    }

                Spacer()

                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        isCheckmarkPressed = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        dismissView()
                    }
                } label: {
                    Image(systemName: "checkmark")
                        .font(.appBody.weight(.semibold))
                        .foregroundColor(.white)
                        .padding(15)
                        .background(
                            Circle()
                                .fill(.white.opacity(0.15))
                        )
                        .scaleEffect(isCheckmarkPressed ? 0.85 : 1.1)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, AppDimensions.screenPadding)
            .padding(.vertical, 16)
            .background(Color.appBackground)

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    VStack(spacing: 12) {

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
                Text("Unforgotten (“we”, “our”, or “us”) is committed to protecting your privacy and handling your personal information responsibly.")
                Text("This Privacy Policy explains how we collect, use, store, and protect your information when you use the Unforgotten mobile application (“App”) and related services.")
                Text("By using the App, you agree to the collection and use of information in accordance with this Privacy Policy.")

            }

            PolicySection(title: "Information We Collect") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("We collect information that you provide directly when using the App. This may include:")
                    .font(.appBodyMedium)

                    Text("Account Information")
                    .font(.appBodyMedium)
                    BulletPoint("Email address")
                    BulletPoint("Login credentials")
                    BulletPoint("Subscription status")
            
                    Text("Profile and Contact Information")
                    .font(.appBodyMedium)
                    BulletPoint("Names of individuals you create profiles for")
                    BulletPoint("Birthdays or important dates")
                    BulletPoint("Photos you upload")
                    BulletPoint("Contact details for useful contacts (such as doctors, family members, or service providers)")

                    Text("Personal Organisation Information")
                    .font(.appBodyMedium)
                    BulletPoint("Tasks and to-do lists")
                    BulletPoint("Notes and reminders")
                    BulletPoint("Calendar events and appointments")        
                    BulletPoint("Sticky reminders and other organisational information")        

                    
                    Text("Health-Related Information (Optional)")
                    .font(.appBodyMedium)
                    BulletPoint("Medication reminders")
                    BulletPoint("Health-related notes")
                    BulletPoint("Appointment tracking")
                    
                    Text("This information is used solely to provide the features of the App.")
                    Text("Users may choose to store information about themselves or about other individuals (such as family members). You are responsible for ensuring you have permission to store information about others.")

                }
            }

            PolicySection(title: "How We Use Your Information") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("We use the information we collect to:")

                    BulletPoint("Provide, maintain, and improve the App")
                    BulletPoint("Enable organisational features such as reminders, tasks, and calendars")
                    BulletPoint("Enable profile management and contact storage")
                    BulletPoint("Support shared access and family collaboration features")
                    BulletPoint("Process subscriptions and payments")
                    BulletPoint("Send service-related notifications such as reminders or account notices")
                    BulletPoint("Respond to support requests and user inquiries")
                    BulletPoint("Maintain the security and reliability of the App")
                    Text("We do not sell your personal data.")

                }
            }

            PolicySection(title: "Family Sharing and Shared Access") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("The App may allow you to invite other users to access shared profiles or information. When you share access:")

                    BulletPoint("Other invited users may be able to view or edit shared information depending on their role or permissions.")
                    BulletPoint("You control who is invited and can remove access at any time.")
                    Text("You should only share access with individuals you trust.")

                }
            }

            PolicySection(title: "Data Storage and Security") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("We take reasonable measures to protect your information.")
                    Text("Data is stored securely using industry-standard security practices. Our backend infrastructure is provided by Supabase, which implements security measures including:")

                    BulletPoint("Encryption of data in transit")
                    BulletPoint("Encryption of stored data")
                    BulletPoint("Role-based access controls and row-level security")
                    BulletPoint("Secure server infrastructure")
                    Text("While we take reasonable steps to protect your information, no system can guarantee absolute security.")

                }
            }
            
            PolicySection(title: "Family Sharing and Shared Access") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("The App may allow you to invite other users to access shared profiles or information. When you share access:")

                    BulletPoint("Other invited users may be able to view or edit shared information depending on their role or permissions.")
                    BulletPoint("You control who is invited and can remove access at any time.")
                    Text("You should only share access with individuals you trust.")

                }
            }           
            
            PolicySection(title: "Data Sharing") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("We do not sell or rent your personal information.")
                    Text("We may share information only in the following limited circumstances:")
                    Text("With Users You Invite")
                    .font(.appBodyMedium)
                    Text("Information may be shared with family members or other users whom you explicitly invite to access shared profiles or information.")
                    Text("With Service Providers")
                    .font(.appBodyMedium)
                    Text("We may use trusted third-party providers (such as cloud infrastructure providers) to operate and maintain the App.")
                    Text("Legal Requirements")
                    .font(.appBodyMedium)
                    Text("We may disclose information if required to do so by law or in response to valid legal requests.")
                    Text("Protection of Rights")
                    .font(.appBodyMedium)
                    Text("We may disclose information where necessary to protect the rights, safety, or integrity of the App or its users.")


                }
            }
            PolicySection(title: "Data Retention") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("We retain your information for as long as your account remains active.")
                    Text("If you delete your account, your personal data will be deleted or anonymized within a reasonable period unless we are legally required to retain certain information.")
                }
            }
            
            PolicySection(title: "Your Rights") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("You have the right to:")

                    BulletPoint("Access the personal data associated with your account")
                    BulletPoint("Correct inaccurate data")
                    BulletPoint("Delete your account and associated data")
                    BulletPoint("Export your stored data where technically feasible")
                    BulletPoint("Withdraw consent for optional features")
                    Text("You can manage most of your data directly within the App.")

                }
            }

            PolicySection(title: "Children's Privacy") {
                Text("The App is not intended for children under the age of 13.")
                Text("We do not knowingly collect personal information from children under 13. If you believe that a child has provided personal information through the App, please contact us and we will promptly remove such information.")

            }

            PolicySection(title: "Changes to This Policy") {
                Text("We may update this Privacy Policy from time to time. When changes are made, the “Last Updated” date at the top of this document will be revised. Continued use of the App after updates indicates acceptance of the revised policy.")
            }

            PolicySection(title: "Contact Us") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("If you have questions about this Privacy Policy, please contact us at:")

                    Link("support@unforgottenapp.com", destination: URL(string: "mailto:support@unforgottenapp.com")!)
                        .foregroundColor(.white)

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
