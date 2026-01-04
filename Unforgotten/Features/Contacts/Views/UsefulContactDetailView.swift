import SwiftUI

// MARK: - Useful Contact Detail View
struct UsefulContactDetailView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @Environment(\.navigateToRoot) var navigateToRoot
    @Environment(\.appAccentColor) private var appAccentColor
    @Environment(\.iPadEditUsefulContactAction) private var iPadEditUsefulContactAction

    @State var contact: UsefulContact
    @State private var showEditContact = false
    @State private var showSettings = false

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header scrolls with content
                CustomizableHeaderView(
                    pageIdentifier: .contactDetail,
                    title: contact.name,
                    subtitle: contact.category.displayName,
                    showBackButton: true,
                    backAction: { dismiss() },
                    showEditButton: true,
                    editAction: {
                        // Use full-screen overlay action if available
                        if let editAction = iPadEditUsefulContactAction {
                            editAction(contact)
                        } else {
                            showEditContact = true
                        }
                    },
                    editButtonPosition: .bottomRight
                )

                // Content
                VStack(spacing: AppDimensions.cardSpacing) {
                        // Action buttons
                        HStack(spacing: 12) {
                            if let phone = contact.phone {
                                ContactActionButton(
                                    icon: "phone.fill",
                                    title: "Call",
                                    color: .badgeGreen
                                ) {
                                    let cleaned = phone.replacingOccurrences(of: " ", with: "")
                                    if let url = URL(string: "tel://\(cleaned)") {
                                        UIApplication.shared.open(url)
                                    }
                                }
                            }

                            if let email = contact.email {
                                ContactActionButton(
                                    icon: "envelope.fill",
                                    title: "Email",
                                    color: .clothingBlue
                                ) {
                                    if let url = URL(string: "mailto:\(email)") {
                                        UIApplication.shared.open(url)
                                    }
                                }
                            }

                            if let website = contact.website {
                                ContactActionButton(
                                    icon: "safari.fill",
                                    title: "Website",
                                    color: .giftPurple
                                ) {
                                    var urlString = website
                                    if !urlString.hasPrefix("http") {
                                        urlString = "https://\(urlString)"
                                    }
                                    if let url = URL(string: urlString) {
                                        UIApplication.shared.open(url)
                                    }
                                }
                            }
                        }

                    // Details
                    if let company = contact.companyName {
                        DetailItemCard(label: "Company", value: company)
                    }

                    if let phone = contact.phone {
                        DetailItemCard(label: "Phone", value: phone)
                    }

                    if let email = contact.email {
                        DetailItemCard(label: "Email", value: email)
                    }

                    if let address = contact.address {
                        Button {
                            let encoded = address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                            if let url = URL(string: "maps://?q=\(encoded)") {
                                UIApplication.shared.open(url)
                            }
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Address")
                                        .font(.appCaption)
                                        .foregroundColor(.textSecondary)

                                    Text(address)
                                        .font(.appCardTitle)
                                        .foregroundColor(.textPrimary)
                                }

                                Spacer()

                                Image(systemName: "map")
                                    .foregroundColor(appAccentColor)
                            }
                            .padding(AppDimensions.cardPadding)
                            .background(Color.cardBackground)
                            .cornerRadius(AppDimensions.cardCornerRadius)
                        }
                    }

                    if let notes = contact.notes {
                        DetailItemCard(label: "Notes", value: notes)
                    }

                    // Bottom spacing for nav bar
                    Spacer()
                        .frame(height: 120)
                }
                .padding(.horizontal, AppDimensions.screenPadding)
                .padding(.top, AppDimensions.cardSpacing)
            }
        }
        .ignoresSafeArea(edges: .top)
        .background(Color.appBackground)
        .navigationBarHidden(true)
        .sidePanel(isPresented: $showSettings) {
            SettingsPanelView(onDismiss: { showSettings = false })
        }
        .sidePanel(isPresented: $showEditContact) {
            EditUsefulContactView(
                contact: contact,
                onDismiss: { showEditContact = false }
            ) { updatedContact in
                contact = updatedContact
            }
        }
    }
}

// MARK: - Contact Action Button
struct ContactActionButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)

                Text(title)
                    .font(.appCaption)
                    .foregroundColor(.textPrimary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.cardBackground)
            .cornerRadius(AppDimensions.cardCornerRadius)
        }
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        UsefulContactDetailView(
            contact: UsefulContact(
                id: UUID(),
                accountId: UUID(),
                name: "Dr. Smith",
                category: .doctor,
                companyName: "Family Medical Center",
                phone: "555-1234",
                email: "dr.smith@example.com",
                website: "familymedical.com",
                address: "123 Medical Drive",
                notes: "Great family doctor",
                isFavourite: false,
                createdAt: Date(),
                updatedAt: Date()
            )
        )
        .environmentObject(AppState())
    }
}
