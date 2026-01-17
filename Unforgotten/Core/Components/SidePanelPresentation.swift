import SwiftUI

// MARK: - Side Panel Dismiss Action
/// Custom dismiss action for side panels
struct SidePanelDismissAction {
    let dismiss: () -> Void

    func callAsFunction() {
        dismiss()
    }
}

// MARK: - Side Panel Dismiss Environment Key
private struct SidePanelDismissKey: EnvironmentKey {
    static let defaultValue: SidePanelDismissAction? = nil
}

extension EnvironmentValues {
    var sidePanelDismiss: SidePanelDismissAction? {
        get { self[SidePanelDismissKey.self] }
        set { self[SidePanelDismissKey.self] = newValue }
    }
}

// MARK: - Side Panel Presentation
/// A view modifier that presents content in a slide-in modal from the right on iPad
/// or as a positioned sheet on smaller screens

struct SidePanelPresentation<PanelContent: View>: ViewModifier {
    @Binding var isPresented: Bool
    let panelContent: () -> PanelContent

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    // Check if we're in iPad mode (regular size class)
    private var isiPad: Bool {
        horizontalSizeClass == .regular
    }

    /// Dismiss action for iPad overlay (needs animation)
    private var iPadDismissAction: SidePanelDismissAction {
        SidePanelDismissAction {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                isPresented = false
            }
        }
    }

    /// Dismiss action for iPhone sheet (no animation needed, SwiftUI handles it)
    private var iPhoneDismissAction: SidePanelDismissAction {
        SidePanelDismissAction {
            isPresented = false
        }
    }

    func body(content: Content) -> some View {
        if isiPad {
            // iPad: Overlay modal sliding from right
            content
                .overlay(alignment: .trailing) {
                    if isPresented {
                        // Dimmed background
                        Color.black.opacity(0.4)
                            .ignoresSafeArea()
                            .onTapGesture {
                                iPadDismissAction()
                            }
                            .transition(.opacity)
                    }
                }
                .overlay(alignment: .topTrailing) {
                    if isPresented {
                        // Slide-in panel from right - constrained to screen height
                        GeometryReader { geometry in
                            let panelWidth = min(max(500, geometry.size.width * 0.4), 650)

                            SlidePanelWrapper(panelWidth: panelWidth, maxHeight: geometry.size.height) {
                                panelContent()
                                    .environment(\.sidePanelDismiss, iPadDismissAction)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                        }
                        .transition(.asymmetric(
                            insertion: .modifier(
                                active: SlidePanelTransition(offset: 680, opacity: 0, scale: 0.95),
                                identity: SlidePanelTransition(offset: 0, opacity: 1, scale: 1)
                            ),
                            removal: .modifier(
                                active: SlidePanelTransition(offset: 680, opacity: 0, scale: 0.95),
                                identity: SlidePanelTransition(offset: 0, opacity: 1, scale: 1)
                            )
                        ))
                    }
                }
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isPresented)
        } else {
            // Compact mode: Use positioned sheet
            content
                .sheet(isPresented: $isPresented) {
                    panelContent()
                        .environment(\.sidePanelDismiss, iPhoneDismissAction)
                        .presentationDetents([.fraction(0.9)])
                        .presentationDragIndicator(.visible)
                        .presentationCornerRadius(24)
                        .presentationBackground(Color.appBackgroundLight)
                }
        }
    }
}

// MARK: - Slide Panel Wrapper
/// Wrapper that fits content with a maximum height constraint
private struct SlidePanelWrapper<Content: View>: View {
    let panelWidth: CGFloat
    let maxHeight: CGFloat
    let content: () -> Content

    /// The panel takes up the full screen height minus padding
    private var panelHeight: CGFloat {
        maxHeight - 80  // Account for top and bottom padding
    }

    var body: some View {
        content()
            .frame(width: panelWidth, height: panelHeight, alignment: .top)
            .background(Color.appBackgroundLight)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: .black.opacity(0.3), radius: 20, x: -5, y: 0)
            .padding(.top, 40)
            .padding(.trailing, 20)
    }
}

// MARK: - Slide Panel Transition
/// Custom transition modifier for the slide panel animation
private struct SlidePanelTransition: ViewModifier {
    let offset: CGFloat
    let opacity: Double
    let scale: CGFloat

    func body(content: Content) -> some View {
        content
            .offset(x: offset)
            .opacity(opacity)
            .scaleEffect(scale, anchor: .trailing)
    }
}

// MARK: - View Extension
extension View {
    /// Presents content in a side panel on iPad full-screen, or as a sheet on smaller screens
    func sidePanel<Content: View>(
        isPresented: Binding<Bool>,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        modifier(SidePanelPresentation(isPresented: isPresented, panelContent: content))
    }

    /// Conditionally presents content in a side panel (only when showPanel is true)
    /// Use this to disable the local sidePanel when iPad uses full-screen overlay instead
    @ViewBuilder
    func conditionalSidePanel<Content: View>(
        isPresented: Binding<Bool>,
        showPanel: Bool,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        if showPanel {
            modifier(SidePanelPresentation(isPresented: isPresented, panelContent: content))
        } else {
            self
        }
    }
}

// MARK: - Side Panel Container
/// A container view for side panel content with consistent styling
struct SidePanelContainer<Content: View>: View {
    let title: String
    let onDismiss: () -> Void
    let content: () -> Content

    @Environment(\.appAccentColor) private var appAccentColor

    init(
        title: String,
        onDismiss: @escaping () -> Void,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.onDismiss = onDismiss
        self.content = content
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.textPrimary)
                        .frame(width: 40, height: 40)
                        .background(Color.cardBackgroundSoft)
                        .clipShape(Circle())
                }

                Spacer()

                Text(title)
                    .font(.appTitle2)
                    .foregroundColor(.textPrimary)

                Spacer()

                // Invisible spacer for centering
                Color.clear
                    .frame(width: 40, height: 40)
            }
            .padding(.horizontal, AppDimensions.screenPadding)
            .padding(.vertical, 16)
            .background(Color.appBackgroundLight)

            // Content
            content()
        }
        .background(Color.appBackgroundLight)
    }
}

// MARK: - Preview
#Preview("Side Panel") {
    struct PreviewWrapper: View {
        @State private var showPanel = false

        var body: some View {
            VStack {
                Button("Show Panel") {
                    showPanel.toggle()
                }
                .padding()

                Text("Main Content")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.blue.opacity(0.2))
            }
            .sidePanel(isPresented: $showPanel) {
                SidePanelContainer(title: "Add Item", onDismiss: { showPanel = false }) {
                    VStack {
                        Text("Panel Content")
                        Spacer()
                    }
                    .padding()
                }
            }
        }
    }

    return PreviewWrapper()
}
