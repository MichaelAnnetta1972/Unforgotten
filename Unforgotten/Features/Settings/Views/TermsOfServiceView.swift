import SwiftUI

// MARK: - Terms of Service View
struct TermsOfServiceView: View {
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
                        Image(systemName: "doc.text.fill")
                            .font(.system(size: 18))
                            .foregroundColor(effectiveAccentColor)
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(effectiveAccentColor.opacity(0.15))
                            )

                        Text("Terms of Service")
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
                    termsContent
                }
                .padding(AppDimensions.screenPadding)
                .padding(.bottom, 40)
            }
        }
        .background(Color.appBackground)
    }

    private var termsContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            PolicySection(title: "Agreement to Terms") {
                Text("By downloading, installing, or using the Unforgotten mobile application (“App”), you agree to be bound by these Terms of Service (“Terms”). If you do not agree to these Terms, you must not access or use the App. These Terms constitute a legally binding agreement between you and Unforgotten regarding your use of the App and any services provided through it.")
            }

            PolicySection(title: "Description of Service") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Unforgotten is a personal organisation and information management application designed to help individuals, families, and caregivers keep important life information organised, accessible, and remembered. The App allows users to store and manage information such as:")

                    BulletPoint("Personal profiles for family members, friends, or contacts")
                    BulletPoint("Calendars, appointments, and important dates")
                    BulletPoint("Birthdays and events")
                    BulletPoint("Tasks, reminders, and notes")
                    BulletPoint("Medication schedules and health-related reminders")
                    BulletPoint("Useful contacts such as doctors, tradespeople, and service providers")
                    BulletPoint("Shared family information and collaborative planning")
                
                    Text("The App may allow users to invite other people to access shared information (for example family members or caregivers) and manage access through permissions or roles.")
                    Text("Unforgotten is designed to help users organise important information in one place so it can be easily remembered and shared.")
                }
            }

            PolicySection(title: "Account Registration") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Certain features of the App require you to create an account. When creating an account, you agree to:")

                    BulletPoint("Provide accurate and complete information")
                    BulletPoint("Maintain and promptly update your account details")
                    BulletPoint("Keep your password and login credentials secure")
                    BulletPoint("Accept responsibility for all activities that occur under your account")
                    BulletPoint("Notify us immediately if you become aware of any unauthorised use of your account")

                    Text("You are responsible for ensuring that anyone you grant access to your account or shared information complies with these Terms.")
                }
            }

            PolicySection(title: "Acceptable Use") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("You agree not to:")

                    BulletPoint("Use the App for any unlawful or harmful purpose")
                    BulletPoint("Upload or store information that infringes the rights of others")
                    BulletPoint("Attempt to gain unauthorised access to the App, its systems, or other users’ accounts")
                    BulletPoint("Interfere with or disrupt the operation or security of the App")
                    BulletPoint("CReverse engineer, decompile, or attempt to extract the source code of the App")
                    BulletPoint("Store personal information about individuals without appropriate consent or lawful basis")
                    BulletPoint("Use the App to harass, exploit, or harm others")

                    Text("You are responsible for ensuring that the information you store in the App is used lawfully and respectfully.")
                }
            }

            PolicySection(title: "Subscriptions and Payments") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Free Plan")
                    .font(.appBodyMedium)
                    Text("Unforgotten may offer a free plan that includes access to core organisational features such as reminders, contacts, calendars, and limited profiles.")

                    Text("Premium Plan")
                    .font(.appBodyMedium)
                    Text("The Premium plan may include additional features such as:")

                    BulletPoint("Unlimited profiles")
                    BulletPoint("Notes and sticky reminders")
                    BulletPoint("To-do lists and task management")
                    BulletPoint("Family or shared account access")
                    BulletPoint("Additional storage and organisation tools")

                    Text("Pricing and features may change from time to time and will be displayed within the App.")

                    Text("Billing")
                    .font(.appBodyMedium)
                    Text("Subscriptions are billed through your Apple ID account.")
                    Text("Subscriptions automatically renew unless cancelled at least 24 hours before the end of the current billing period.")
                    Text("You may manage or cancel your subscription through your App Store account settings.")

                }
            }

            PolicySection(title: "Medical Disclaimer") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Unforgotten is not a medical device and does not provide medical advice.")
                    Text("While the App may allow users to track medications or health-related information, it is intended only as an organisational tool.")
                    Text("You acknowledge that:")

                    BulletPoint("The App does not diagnose, treat, cure, or prevent any disease or medical condition")
                    BulletPoint("Medication reminders and health information should always be verified with qualified healthcare professionals")
                    BulletPoint("You should not rely solely on the App for medical decisions or medication management")
                    BulletPoint("In case of a medical emergency, you should contact emergency services immediately")
                    Text("Unforgotten is not responsible for any health outcomes resulting from the use or misuse of the App.")

                }
            }

            PolicySection(title: "User Content") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("You retain ownership of any information, data, or content that you enter into the App (“User Content”).")
                    Text("By using the App, you grant Unforgotten a limited license to:")

                    BulletPoint("Store")
                    BulletPoint("Process")
                    BulletPoint("Display")
                    BulletPoint("Transmit")
                    Text("your content solely for the purpose of operating and providing the App’s services.")
                    Text("You represent and warrant that:")

                    BulletPoint("You have the right to store the information you enter")
                    BulletPoint("You have obtained any required consent from individuals whose information you store")
                    BulletPoint("Your content does not violate any laws or third-party rights")

                }
            }
            PolicySection(title: "Acceptable Use") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("You agree not to:")
                    BulletPoint("Use the App for any unlawful or harmful purpose")
                    BulletPoint("Upload or store information that infringes the rights of others")
                    BulletPoint("Attempt to gain unauthorized access to the App, its systems, or other users’ accounts")
                    BulletPoint("Interfere with or disrupt the operation or security of the App")
                    BulletPoint("Reverse engineer, decompile, or attempt to extract the source code of the App")
                    BulletPoint("Store personal information about individuals without appropriate consent or lawful basis")
                    BulletPoint("Use the App to harass, exploit, or harm others")
                    Text("You are responsible for ensuring that the information you store in the App is used lawfully and respectfully.")
                }
            }
            PolicySection(title: "Intellectual Property") {
                Text("The App, including its design, software, features, branding, and content (excluding User Content), is owned by Unforgotten and is protected by copyright, trademark, and other intellectual property laws.")
                Text("You are granted a limited, non-exclusive, non-transferable license to use the App for personal use in accordance with these Terms.")
            }

            PolicySection(title: "Limitation of Liability") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("To the maximum extent permitted by law, Unforgotten shall not be liable for:")

                    BulletPoint("Indirect, incidental, special, consequential, or punitive damages")
                    BulletPoint("Loss of profits, data, or business opportunities")
                    BulletPoint("Unauthorised access to or alteration of your data")
                    BulletPoint("Interruptions, errors, or outages of the App")
                    BulletPoint("Any reliance on information stored in the App")
                    Text("Our total liability for any claim relating to the App shall not exceed the amount you paid to us in the 12 months preceding the claim.")

                }
            }

            PolicySection(title: "Disclaimer of Warranties") {
                Text("The App is provided “as is” and “as available” without warranties of any kind, whether express or implied.")
                Text("We do not guarantee that the App will be uninterrupted, error-free, secure, or suitable for every purpose.")
            }

            PolicySection(title: "Termination") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("We may suspend or terminate your account at any time if you violate these Terms or misuse the App.")
                    Text("You may stop using the App at any time.")
                    Text("Upon termination, your right to access the App will cease. Where possible, you may request an export of your data prior to account closure.")
                        .padding(.top, 8)
                }
            }

            PolicySection(title: "Changes to Terms") {
                Text("We may update these Terms from time to time.")
                Text("If we make material changes, we will update the “Last Updated” date and may notify users through the App.")
                Text("Your continued use of the App after changes take effect constitutes acceptance of the updated Terms.")

            }

            PolicySection(title: "Governing Law") {
                Text("These Terms are governed by the laws of the jurisdiction in which Unforgotten operates, without regard to conflict of law principles.")
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
