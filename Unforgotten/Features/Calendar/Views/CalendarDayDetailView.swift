import SwiftUI

// MARK: - Calendar Day Detail View
struct CalendarDayDetailView: View {
    let date: Date
    let events: [CalendarEvent]
    @Binding var isPresented: Bool
    var onEventSelected: ((CalendarEvent) -> Void)?

    @Environment(\.appAccentColor) private var appAccentColor
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State private var opacity: Double = 0
    @State private var scale: CGFloat = 0.9

    /// Panel width - wider on iPad
    private var panelWidth: CGFloat {
        horizontalSizeClass == .regular ? 500 : UIScreen.main.bounds.width - 40
    }


    var body: some View {
        ZStack {
            // Dimmed background
            Color.cardBackground.opacity(0.8)
                .ignoresSafeArea()
                .onTapGesture {
                    dismissPanel()
                }

            // Centered panel
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 4) {
                    HStack {
                        Spacer()

                        VStack(spacing: 4) {
                            Text(dayName)
                                .font(.appTitle)
                                .foregroundColor(.textPrimary)

                            Text(fullDateString)
                                .font(.appBody)
                                .foregroundColor(.textSecondary)
                        }

                        Spacer()

                        Button {
                            dismissPanel()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.textSecondary)
                        }
                    }
                }
                .padding(AppDimensions.cardPadding)

                Divider()
                    .background(Color.cardBackground)

                // Events list
                if events.isEmpty {
                    emptyStateView
                } else {
                    VStack(spacing: AppDimensions.cardSpacing) {
                        ForEach(events) { event in
                            Button {
                                handleEventTap(event)
                            } label: {
                                CalendarEventRow(event: event, showFullDetails: true, style: .filled)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(AppDimensions.cardPadding)
                }

                // Done button
             //   Button {
             //       dismissPanel()
             //   } label: {
             //       Text("Done")
             //           .font(.appCardTitle)
             //           .foregroundColor(.black)
             //           .frame(maxWidth: .infinity)
             //           .padding(.vertical, 16)
             //           .background(appAccentColor)
             //           .cornerRadius(AppDimensions.cardCornerRadius)
             //   }
             //   .padding(AppDimensions.cardPadding)
            }
            .frame(width: panelWidth)
            .background(Color.cardBackgroundLight)
            .clipShape(RoundedRectangle(cornerRadius: AppDimensions.cardCornerRadius))
            .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
            .scaleEffect(scale)
            .opacity(opacity)
        }
        .onAppear {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                opacity = 1.0
                scale = 1.0
            }
        }
    }

    private func handleEventTap(_ event: CalendarEvent) {
        // Dismiss the panel first, then trigger navigation
        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
            opacity = 0
            scale = 0.9
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            isPresented = false
            onEventSelected?(event)
        }
    }

    private func dismissPanel() {
        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
            opacity = 0
            scale = 0.9
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            isPresented = false
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.checkmark")
                .font(.system(size: 48))
                .foregroundColor(.textSecondary)

            Text("No Events")
                .font(.appTitle)
                .foregroundColor(.textPrimary)

            Text("No events scheduled for this day.")
                .font(.appBody)
                .foregroundColor(.textSecondary)
        }
        .padding(AppDimensions.cardPadding)
    }

    // MARK: - Helper Properties

    private var dayName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: date)
    }

    private var fullDateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d, yyyy"
        return formatter.string(from: date)
    }
}

// MARK: - Preview
#Preview {
    ZStack {
        Color.appBackgroundLight.ignoresSafeArea()

        CalendarDayDetailView(
            date: Date(),
            events: [],
            isPresented: .constant(true)
        )
    }
}
