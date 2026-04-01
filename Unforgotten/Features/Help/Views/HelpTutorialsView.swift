import SwiftUI

// MARK: - Help & Tutorials View
struct HelpTutorialsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.sidePanelDismiss) private var sidePanelDismiss
    @Environment(\.appAccentColor) private var appAccentColor
    @Environment(UserPreferences.self) private var userPreferences
    @Environment(HeaderStyleManager.self) private var headerStyleManager
    @State private var isCheckmarkPressed = false

    private let groupedTutorials: [TutorialCategory: [Tutorial]] = {
        Dictionary(grouping: Tutorial.allTutorials, by: { $0.category })
    }()

    private var effectiveAccentColor: Color {
        if userPreferences.hasCustomAccentColor {
            return userPreferences.accentColor
        } else {
            return headerStyleManager.defaultAccentColor
        }
    }

    private func dismissView() {
        if let sidePanelDismiss {
            sidePanelDismiss()
        } else {
            dismiss()
        }
    }

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    HStack(spacing: 12) {
                        Image(systemName: "questionmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(effectiveAccentColor)
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(effectiveAccentColor.opacity(0.15))
                            )

                        Text("Help & Tutorials")
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

                ScrollView(.vertical) {
                    VStack(spacing: 24) {
                        // Intro text
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Video Tutorials")
                                .font(.appCardTitle)
                                .foregroundColor(.textPrimary)
                            Text("Short guides to help you use every feature with confidence.")
                                .font(.appBody)
                                .foregroundColor(.textSecondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, AppDimensions.screenPadding)
                        .padding(.top, 8)

                        // Tutorial sections grouped by category
                        ForEach(TutorialCategory.allCases, id: \.self) { category in
                            if let tutorials = groupedTutorials[category] {
                                tutorialSection(category: category, tutorials: tutorials)
                            }
                        }

                        // YouTube channel link
                        // youTubeChannelLink
                        //     .padding(.horizontal, AppDimensions.screenPadding)

                        Spacer()
                            .frame(height: 40)
                    }
                }
            }
        }
    }

    // MARK: - Tutorial Section
    @ViewBuilder
    private func tutorialSection(category: TutorialCategory, tutorials: [Tutorial]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(category.rawValue.uppercased())
                .font(.appCaption)
                .foregroundColor(effectiveAccentColor)
                .padding(.horizontal, AppDimensions.screenPadding)

            VStack(spacing: 1) {
                ForEach(tutorials) { tutorial in
                    TutorialRowView(tutorial: tutorial)
                }
            }
            .background(Color.cardBackground)
            .cornerRadius(AppDimensions.cardCornerRadius)
            .padding(.horizontal, AppDimensions.screenPadding)
        }
    }

    // MARK: - YouTube Channel Link
    // private var youTubeChannelLink: some View {
    //     Button {
    //         if let url = URL(string: "https://www.youtube.com/@UnforgottenApp") {
    //             UIApplication.shared.open(url)
    //         }
    //     } label: {
    //         HStack(spacing: 12) {
    //             Image(systemName: "play.rectangle.fill")
    //                 .foregroundColor(.red)
    //                 .font(.title3)

    //             VStack(alignment: .leading, spacing: 2) {
    //                 Text("Visit our YouTube Channel")
    //                     .font(.appBody)
    //                     .foregroundColor(.textPrimary)
    //                 Text("See all tutorials and new guides")
    //                     .font(.appCaption)
    //                     .foregroundColor(.textSecondary)
    //             }

    //             Spacer()

    //             Image(systemName: "arrow.up.right")
    //                 .foregroundColor(.textSecondary)
    //                 .font(.appCaption)
    //         }
    //         .padding()
    //         .background(Color.cardBackground)
    //         .cornerRadius(AppDimensions.cardCornerRadius)
    //     }
    // }
}

// MARK: - Tutorial Row View
struct TutorialRowView: View {
    let tutorial: Tutorial
    @Environment(\.appAccentColor) private var appAccentColor
    @State private var showPlayer = false

    var body: some View {
        Button {
            showPlayer = true
        } label: {
            HStack(spacing: 16) {
                // Icon
                Image(systemName: tutorial.iconName)
                    .font(.title3)
                    .foregroundColor(appAccentColor)
                    .frame(width: 32)

                // Text
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(tutorial.title)
                            .font(.appBodyMedium)
                            .foregroundColor(.textPrimary)

                        // Duration badge
                        Text(tutorial.duration)
                            .font(.appCaptionSmall)
                            .foregroundColor(.textSecondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.cardBackgroundLight)
                            .clipShape(Capsule())
                            .fixedSize()
                    }   

                    Text(tutorial.description)
                        .font(.appCaption)
                        .foregroundColor(.textSecondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                .frame(minWidth: 0)

                Spacer(minLength: 4)



                Image(systemName: "chevron.right")
                    .foregroundColor(.textSecondary)
                    .font(.appCaption)
            }
            .padding()
            .background(Color.cardBackground)
        }
        .fullScreenCover(isPresented: $showPlayer) {
            FullscreenVideoPlayerView(tutorial: tutorial)
        }
    }
}
