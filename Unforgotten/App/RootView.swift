import SwiftUI

struct RootView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        Group {
            if appState.isLoading {
                LoadingScreen()
            } else if !appState.isAuthenticated {
                AuthView()
            } else if !appState.hasCompletedOnboarding {
                OnboardingView()
            } else {
                MainAppView()
                    .sheet(isPresented: $appState.showMoodPrompt) {
                        MoodPromptView()
                    }
            }
        }
        .animation(.easeInOut, value: appState.isAuthenticated)
        .animation(.easeInOut, value: appState.hasCompletedOnboarding)
    }
}

// MARK: - Loading Screen
struct LoadingScreen: View {
    var body: some View {
        ZStack {
            // Background image
            Image("loading-background")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .ignoresSafeArea()

            // Dark overlay for better text readability
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                // App icon placeholder
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 80))
                    .foregroundColor(.accentYellow)

                Text("Unforgotten")
                    .font(.appLargeTitle)
                    .foregroundColor(.textPrimary)

                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .accentYellow))
                    .scaleEffect(1.2)
            }
        }
    }
}

// MARK: - Main App View (iPhone)
struct MainAppView: View {
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    var body: some View {
        // For now, we'll use iPhone layout for MVP
        // iPad NavigationSplitView can be added in Phase 2
        IPhoneMainView()
    }
}

// MARK: - iPhone Main View
struct IPhoneMainView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedTab: NavDestination = .home
    @State private var slideDirection: SlideDirection = .none
    @State private var showAddProfile = false
    @State private var showAddMedication = false
    @State private var showAddAppointment = false
    @State private var showAddContact = false
    @State private var homePath = NavigationPath()
    @State private var profilesPath = NavigationPath()
    @State private var appointmentsPath = NavigationPath()
    @State private var medicationsPath = NavigationPath()
    @Namespace private var navNamespace

    // Determine if we're at the root of the current tab
    private var isAtHomeRoot: Bool {
        homePath.isEmpty
    }

    var body: some View {
        ZStack {
            // Tab content with slide transition
            TabContentView(
                selectedTab: selectedTab,
                slideDirection: slideDirection,
                navNamespace: navNamespace,
                homePath: $homePath,
                profilesPath: $profilesPath,
                appointmentsPath: $appointmentsPath,
                medicationsPath: $medicationsPath
            )
            .environment(\.navNamespace, navNamespace)

            // Persistent bottom nav bar
            BottomNavBar(
                currentPage: selectedTab,
                isAtHomeRoot: isAtHomeRoot,
                onNavigate: { newTab in
                    navigateToTab(newTab)
                },
                onAddProfile: { showAddProfile = true },
                onAddMedication: { showAddMedication = true },
                onAddAppointment: { showAddAppointment = true },
                onAddContact: { showAddContact = true }
            )
        }
        .sheet(isPresented: $showAddProfile) {
            AddProfileView { _ in }
        }
        .sheet(isPresented: $showAddMedication) {
            AddMedicationView { _ in }
        }
        .sheet(isPresented: $showAddAppointment) {
            AddAppointmentView { _ in }
        }
        .sheet(isPresented: $showAddContact) {
            AddUsefulContactView { _ in }
        }
    }

    private func navigateToTab(_ newTab: NavDestination) {
        // If tapping home while on home tab but not at root, go back to root
        if newTab == .home && selectedTab == .home && !isAtHomeRoot {
            withAnimation(.easeInOut(duration: 0.3)) {
                homePath = NavigationPath()
            }
            return
        }

        guard newTab != selectedTab else { return }

        // Determine slide direction based on tab order
        let tabOrder: [NavDestination] = [.home, .profiles, .appointments, .medications]
        let currentIndex = tabOrder.firstIndex(of: selectedTab) ?? 0
        let newIndex = tabOrder.firstIndex(of: newTab) ?? 0

        slideDirection = newIndex > currentIndex ? .left : .right

        withAnimation(.easeInOut(duration: 0.3)) {
            selectedTab = newTab
        }
    }
}

// MARK: - Slide Direction
enum SlideDirection {
    case left
    case right
    case none
}

// MARK: - Tab Content View
struct TabContentView: View {
    let selectedTab: NavDestination
    let slideDirection: SlideDirection
    let navNamespace: Namespace.ID
    @Binding var homePath: NavigationPath
    @Binding var profilesPath: NavigationPath
    @Binding var appointmentsPath: NavigationPath
    @Binding var medicationsPath: NavigationPath

    var body: some View {
        ZStack {
            // Each tab has its own NavigationStack for internal navigation
            switch selectedTab {
            case .home:
                NavigationStack(path: $homePath) {
                    HomeView()
                        .navigationDestination(for: HomeDestination.self) { destination in
                            destinationView(for: destination)
                        }
                }
                .tint(.accentYellow)
                .transition(slideTransition)

            case .profiles:
                NavigationStack(path: $profilesPath) {
                    ProfileListView()
                        .navigationDestination(for: HomeDestination.self) { destination in
                            destinationView(for: destination)
                        }
                }
                .tint(.accentYellow)
                .transition(slideTransition)

            case .appointments:
                NavigationStack(path: $appointmentsPath) {
                    AppointmentListView()
                        .navigationDestination(for: HomeDestination.self) { destination in
                            destinationView(for: destination)
                        }
                }
                .tint(.accentYellow)
                .transition(slideTransition)

            case .medications:
                NavigationStack(path: $medicationsPath) {
                    MedicationListView()
                        .navigationDestination(for: HomeDestination.self) { destination in
                            destinationView(for: destination)
                        }
                }
                .tint(.accentYellow)
                .transition(slideTransition)

            case .other:
                EmptyView()
            }
        }
    }

    private var slideTransition: AnyTransition {
        switch slideDirection {
        case .left:
            return .asymmetric(
                insertion: .move(edge: .trailing),
                removal: .move(edge: .leading)
            )
        case .right:
            return .asymmetric(
                insertion: .move(edge: .leading),
                removal: .move(edge: .trailing)
            )
        case .none:
            return .opacity
        }
    }

    @ViewBuilder
    private func destinationView(for destination: HomeDestination) -> some View {
        switch destination {
        case .myCard:
            MyCardView()
                .navigationTransition(.zoom(sourceID: destination, in: navNamespace))
        case .profiles:
            ProfileListView()
                .navigationTransition(.zoom(sourceID: destination, in: navNamespace))
        case .medications:
            MedicationListView()
                .navigationTransition(.zoom(sourceID: destination, in: navNamespace))
        case .appointments:
            AppointmentListView()
                .navigationTransition(.zoom(sourceID: destination, in: navNamespace))
        case .birthdays:
            BirthdaysView()
                .navigationTransition(.zoom(sourceID: destination, in: navNamespace))
        case .contacts:
            UsefulContactsListView()
                .navigationTransition(.zoom(sourceID: destination, in: navNamespace))
        case .mood:
            MoodDashboardView()
                .navigationTransition(.zoom(sourceID: destination, in: navNamespace))
        }
    }
}

// MARK: - Navigate to Root Environment Key
private struct NavigateToRootKey: EnvironmentKey {
    static let defaultValue: () -> Void = {}
}

extension EnvironmentValues {
    var navigateToRoot: () -> Void {
        get { self[NavigateToRootKey.self] }
        set { self[NavigateToRootKey.self] = newValue }
    }
}

// MARK: - Nav Namespace Environment Key
private struct NavNamespaceKey: EnvironmentKey {
    @Namespace static var defaultNamespace
    static let defaultValue: Namespace.ID = defaultNamespace
}

extension EnvironmentValues {
    var navNamespace: Namespace.ID {
        get { self[NavNamespaceKey.self] }
        set { self[NavNamespaceKey.self] = newValue }
    }
}

// MARK: - Preview
#Preview {
    RootView()
        .environmentObject(AppState())
}
