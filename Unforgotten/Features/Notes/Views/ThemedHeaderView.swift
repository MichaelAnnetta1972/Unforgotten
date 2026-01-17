import SwiftUI

// MARK: - Themed Header View
/// Collapsible parallax header with theme-specific styling
struct ThemedHeaderView: View {
    let theme: NoteTheme
    let scrollOffset: CGFloat
    var expandedHeight: CGFloat = NoteSpacing.headerExpandedHeight
    var collapsedHeight: CGFloat = NoteSpacing.headerCollapsedHeight

    // Computed properties for parallax effect
    private var headerHeight: CGFloat {
        let height = expandedHeight + scrollOffset
        return max(collapsedHeight, height)
    }

    private var collapseProgress: CGFloat {
        let progress = (expandedHeight - headerHeight) / (expandedHeight - collapsedHeight)
        return min(max(progress, 0), 1)
    }

    private var iconScale: CGFloat {
        1 - (collapseProgress * 0.3)
    }

    private var iconOpacity: Double {
        1 - Double(collapseProgress)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // Gradient background
            LinearGradient(
                colors: theme.headerGradientColors,
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: headerHeight)

            // Decorative pattern
            decorativePattern
                .opacity(iconOpacity * theme.patternOpacity)

            // Bottom fade
            LinearGradient(
                colors: [.clear, Color.noteBackground],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 40)
        }
        .frame(height: headerHeight)
        .clipped()
    }

    // MARK: - Decorative Pattern

    private var decorativePattern: some View {
        GeometryReader { geometry in
            ZStack {
                // Scattered decorative icons
                ForEach(0..<8, id: \.self) { index in
                    let icon = theme.decorativeIcons[index % theme.decorativeIcons.count]
                    let xOffset = CGFloat(index % 4) * (geometry.size.width / 3)
                    let yOffset = CGFloat(index / 4) * 60 + 20

                    Image(systemName: icon)
                        .font(.system(size: 24 + CGFloat(index % 3) * 8))
                        .foregroundColor(theme.accentColor)
                        .rotationEffect(.degrees(Double(index) * 15 - 30))
                        .offset(
                            x: xOffset - geometry.size.width / 6 + (scrollOffset * 0.1),
                            y: yOffset + (scrollOffset * 0.05 * CGFloat(index % 3))
                        )
                        .scaleEffect(iconScale)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
    }
}

// MARK: - Mini Theme Header
/// Smaller header for compact displays
struct MiniThemeHeader: View {
    let theme: NoteTheme
    var height: CGFloat = 120

    var body: some View {
        ZStack(alignment: .bottom) {
            LinearGradient(
                colors: theme.headerGradientColors,
                startPoint: .top,
                endPoint: .bottom
            )

            // Single centered icon
            Image(systemName: theme.icon)
                .font(.system(size: 32, weight: .light))
                .foregroundColor(theme.accentColor.opacity(0.3))
                .offset(y: -20)
        }
        .frame(height: height)
    }
}

// MARK: - Editor Header View
/// Header specifically designed for the note editor with parallax scrolling
struct EditorHeaderView: View {
    let theme: NoteTheme
    let scrollOffset: CGFloat
    @Binding var title: String
    @FocusState.Binding var isTitleFocused: Bool

    private var expandedHeight: CGFloat { NoteSpacing.headerExpandedHeight }
    private var collapsedHeight: CGFloat { NoteSpacing.headerCollapsedHeight }

    private var headerHeight: CGFloat {
        let height = expandedHeight + scrollOffset
        return max(collapsedHeight, height)
    }

    private var collapseProgress: CGFloat {
        let progress = (expandedHeight - headerHeight) / (expandedHeight - collapsedHeight)
        return min(max(progress, 0), 1)
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Theme gradient
            LinearGradient(
                colors: theme.headerGradientColors,
                startPoint: .top,
                endPoint: .bottom
            )

            // Decorative icons (fade on collapse)
            decorativeIcons
                .opacity(1 - Double(collapseProgress))

            // Title field
            titleField
                .padding(.horizontal, NoteSpacing.editorHorizontalPadding)
                .padding(.bottom, 16)
        }
        .frame(height: headerHeight)
        .clipped()
    }

    private var decorativeIcons: some View {
        HStack(spacing: 24) {
            ForEach(theme.decorativeIcons.prefix(3), id: \.self) { icon in
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .light))
                    .foregroundColor(theme.accentColor.opacity(0.4))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        .padding(.top, 60)
        .padding(.trailing, 20)
    }

    private var titleField: some View {
        TextField("Title", text: $title)
            .font(NoteTypography.noteTitle)
            .foregroundColor(.notePrimaryText)
            .focused($isTitleFocused)
            .submitLabel(.next)
    }
}

// MARK: - Preview
#Preview("Themed Headers") {
    ScrollView {
        VStack(spacing: 32) {
            ForEach(NoteTheme.allCases) { theme in
                VStack(alignment: .leading, spacing: 8) {
                    Text(theme.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)

                    ThemedHeaderView(
                        theme: theme,
                        scrollOffset: 0
                    )
                }
            }
        }
    }
}

#Preview("Header Collapse") {
    struct CollapsePreview: View {
        @State private var offset: CGFloat = 0

        var body: some View {
            VStack {
                ThemedHeaderView(
                    theme: .festive,
                    scrollOffset: offset
                )

                Slider(value: $offset, in: -150...50)
                    .padding()

                Spacer()
            }
        }
    }

    return CollapsePreview()
}
