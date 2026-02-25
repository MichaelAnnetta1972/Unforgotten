import SwiftUI

// MARK: - Family Tree View
/// An interactive radial family tree visualization with the primary person at the center
struct FamilyTreeView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @Environment(\.appAccentColor) private var appAccentColor
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State private var profiles: [Profile] = []
    @State private var primaryProfile: Profile?
    @State private var selectedProfile: Profile?
    @State private var focusedProfile: Profile?  // The profile currently at center
    @State private var isLoading = true
    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var containerSize: CGSize = .zero

    /// Whether we're on iPad
    private var isIPad: Bool {
        horizontalSizeClass == .regular
    }

    /// The parent of the currently focused profile (for navigation back)
    private var focusedParent: Profile? {
        guard let focused = focusedProfile,
              let parentId = focused.connectedToProfileId else {
            // If focused is primary or has no connection, parent is primary
            if focusedProfile?.id != primaryProfile?.id {
                return primaryProfile
            }
            return nil
        }
        return profiles.first { $0.id == parentId }
    }

    /// Organized profiles relative to the focused profile
    private var organizedProfiles: [FamilyTreeNode] {
        buildFocusedTree()
    }

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            if isLoading {
                ProgressView()
                    .tint(appAccentColor)
            } else if profiles.isEmpty {
                emptyStateView
            } else {
                GeometryReader { geometry in
                    let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)

                    ZStack {
                        // Connection lines (using circle centers, not VStack centers)
                        ForEach(organizedProfiles) { node in
                            if let connectedId = node.connectedToProfileId,
                               let connectedNode = organizedProfiles.first(where: { $0.id == connectedId }) {
                                ConnectionLine(
                                    from: nodeCircleCenter(for: node, center: center, containerSize: geometry.size, isMini: node.ring > 1),
                                    to: nodeCircleCenter(for: connectedNode, center: center, containerSize: geometry.size, isMini: connectedNode.ring > 1),
                                    color: appAccentColor.opacity(0.3)
                                )
                            }
                        }

                        // Profile nodes - full view for ring 0 and 1, mini for ring 2+
                        ForEach(organizedProfiles) { node in
                            if node.ring == 0 {
                                // Center/focused node - tap to show details
                                FamilyTreeNodeView(
                                    node: node,
                                    isSelected: selectedProfile?.id == node.profile.id,
                                    isFocused: true,
                                    accentColor: appAccentColor
                                )
                                .position(nodePosition(for: node, center: center, containerSize: geometry.size))
                                .onTapGesture {
                                    selectProfile(node: node, center: center, containerSize: geometry.size)
                                }
                            } else if node.ring == 1 {
                                // Ring 1 nodes - tap to focus on them (make them center)
                                FamilyTreeNodeView(
                                    node: node,
                                    isSelected: selectedProfile?.id == node.profile.id,
                                    isFocused: false,
                                    accentColor: appAccentColor
                                )
                                .position(nodePosition(for: node, center: center, containerSize: geometry.size))
                                .onTapGesture {
                                    focusOnProfile(node.profile)
                                }
                            } else {
                                // Mini node view for ring 2+
                                MiniNodeView(
                                    node: node,
                                    accentColor: appAccentColor
                                )
                                .position(nodePosition(for: node, center: center, containerSize: geometry.size))
                                .onTapGesture {
                                    focusOnProfile(node.profile)
                                }
                            }
                        }
                    }
                    .scaleEffect(scale)
                    .offset(offset)
                    .gesture(
                        MagnificationGesture()
                            .onChanged { value in
                                scale = min(max(value, 0.5), 2.0)
                            }
                    )
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                offset = CGSize(
                                    width: lastOffset.width + value.translation.width,
                                    height: lastOffset.height + value.translation.height
                                )
                            }
                            .onEnded { _ in
                                lastOffset = offset
                            }
                    )
                    .onAppear {
                        containerSize = geometry.size
                    }
                    .onChange(of: geometry.size) { _, newSize in
                        containerSize = newSize
                    }
                }
                .background(Color.appBackgroundSoft)
                .clipShape(RoundedRectangle(cornerRadius: AppDimensions.cardCornerRadius))
                .padding(AppDimensions.screenPadding)
                .padding(.bottom, 40)
            }

            // Selected profile detail card with high z-index
            if let profile = selectedProfile {
                profileDetailCardOverlay(for: profile)
                    .zIndex(100)
            }
        }
        .navigationTitle("Family Tree")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // Parent navigation button (when not viewing primary)
            ToolbarItem(placement: .topBarLeading) {
                if let parent = focusedParent {
                    Button {
                        focusOnProfile(parent)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text(parent.displayName)
                                .lineLimit(1)
                        }
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(appAccentColor)
                    }
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 16) {
                    // Home button to go back to primary
                    if focusedProfile?.id != primaryProfile?.id {
                        Button {
                            if let primary = primaryProfile {
                                focusOnProfile(primary)
                            }
                        } label: {
                            Image(systemName: "house")
                                .foregroundColor(.textPrimary)
                        }
                    }

                    // Reset view button
                    Button {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            scale = 1.0
                            offset = .zero
                            lastOffset = .zero
                            selectedProfile = nil
                        }
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                            .foregroundColor(.textPrimary)
                    }
                }
            }
        }
        .task {
            await loadProfiles()
        }
    }

    // MARK: - Select Profile
    private func selectProfile(node: FamilyTreeNode, center: CGPoint, containerSize: CGSize) {
        // Trigger haptic feedback
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()

        if selectedProfile?.id == node.profile.id {
            // Deselect and reset view
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                selectedProfile = nil
                offset = .zero
                lastOffset = .zero
            }
        } else {
            // Calculate offset to center the selected node
            let nodePos = nodePosition(for: node, center: center, containerSize: containerSize)
            let targetOffset = CGSize(
                width: center.x - nodePos.x,
                height: center.y - nodePos.y
            )

            // Animate to center the selected profile
            withAnimation(.spring(response: 0.6, dampingFraction: 0.75)) {
                selectedProfile = node.profile
                offset = targetOffset
                lastOffset = targetOffset
            }

            // Additional haptic for selection confirmation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                let selection = UISelectionFeedbackGenerator()
                selection.selectionChanged()
            }
        }
    }

    // MARK: - Focus on Profile
    /// Changes the focused profile to show it at the center with its connections around it
    private func focusOnProfile(_ profile: Profile) {
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()

        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            focusedProfile = profile
            selectedProfile = nil
            offset = .zero
            lastOffset = .zero
            scale = 1.0
        }
    }

    // MARK: - Profile Detail Card Overlay
    @ViewBuilder
    private func profileDetailCardOverlay(for profile: Profile) -> some View {
        if isIPad {
            // iPad: Position card at bottom left
            VStack {
                Spacer()
                HStack {
                    ProfileDetailCard(
                        profile: profile,
                        connectedToProfile: profiles.first { $0.id == profile.connectedToProfileId },
                        onClose: {
                            let impact = UIImpactFeedbackGenerator(style: .light)
                            impact.impactOccurred()
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                selectedProfile = nil
                                offset = .zero
                                lastOffset = .zero
                            }
                        }
                    )
                    .padding(.leading, 24)
                    .padding(.bottom, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))

                    Spacer()
                }
            }
        } else {
            // iPhone: Position card at the bottom
            VStack {
                Spacer()
                ProfileDetailCard(
                    profile: profile,
                    connectedToProfile: profiles.first { $0.id == profile.connectedToProfileId },
                    onClose: {
                        let impact = UIImpactFeedbackGenerator(style: .light)
                        impact.impactOccurred()
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            selectedProfile = nil
                            offset = .zero
                            lastOffset = .zero
                        }
                    }
                )
                .padding(.horizontal)
                .padding(.bottom, 60)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.3")
                .font(.system(size: 60))
                .foregroundColor(.textSecondary)

            Text("No Family Members Yet")
                .font(.appTitle)
                .foregroundColor(.textPrimary)

            Text("Add family members and connect them to build your family tree")
                .font(.appBody)
                .foregroundColor(.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }

    // MARK: - Load Profiles
    private func loadProfiles() async {
        guard let accountId = appState.currentAccount?.id else {
            isLoading = false
            return
        }

        do {
            profiles = try await appState.profileRepository.getProfiles(accountId: accountId)
            primaryProfile = profiles.first { $0.type == .primary }
            // Initialize focused profile to primary
            if focusedProfile == nil {
                focusedProfile = primaryProfile
            }
            isLoading = false
        } catch {
            #if DEBUG
            print("Failed to load profiles: \(error)")
            #endif
            isLoading = false
        }
    }

    // MARK: - Relationship Categories
    /// Relationships that directly connect to the Primary person (ring 1)
    private static let directRelationships: Set<String> = [
        "Mother", "Father", "Son", "Daughter", "Brother", "Sister",
        "Spouse", "Partner", "Ex Spouse",
        "Grandmother", "Grandfather",
        "Aunt", "Uncle",
        "Friend", "Carer", "Doctor", "Dentist", "Neighbour",
        "Colleague", "Lawyer", "Accountant", "Other"
    ]

    /// Relationships that connect through a child (Son/Daughter) - ring 2
    private static let grandchildRelationships: Set<String> = [
        "Grandson", "Granddaughter"
    ]

    /// Relationships that connect through a sibling (Brother/Sister) - ring 2
    private static let niblingRelationships: Set<String> = [
        "Nephew", "Niece"
    ]

    /// Child relationships (for finding grandchild parents)
    private static let childRelationships: Set<String> = [
        "Son", "Daughter"
    ]

    /// Sibling relationships (for finding nibling parents)
    private static let siblingRelationships: Set<String> = [
        "Brother", "Sister"
    ]

    // MARK: - Infer Connection
    /// Determines who a profile should connect to based on their relationship
    private func inferConnection(for profile: Profile, primaryId: UUID, allProfiles: [Profile]) -> UUID? {
        // If they have an explicit connection, use it
        if let explicitConnection = profile.connectedToProfileId {
            return explicitConnection
        }

        guard let relationship = profile.relationship else { return nil }

        // Direct relationships connect to primary
        if Self.directRelationships.contains(relationship) {
            return primaryId
        }

        // Grandchildren connect to the first available Son/Daughter
        if Self.grandchildRelationships.contains(relationship) {
            if let parent = allProfiles.first(where: { p in
                p.id != profile.id &&
                p.type != .primary &&
                Self.childRelationships.contains(p.relationship ?? "")
            }) {
                return parent.id
            }
            // Fallback to primary if no child found
            return primaryId
        }

        // Nieces/Nephews connect to the first available Brother/Sister
        if Self.niblingRelationships.contains(relationship) {
            if let sibling = allProfiles.first(where: { p in
                p.id != profile.id &&
                p.type != .primary &&
                Self.siblingRelationships.contains(p.relationship ?? "")
            }) {
                return sibling.id
            }
            // Fallback to primary if no sibling found
            return primaryId
        }

        // Cousin connects to Aunt/Uncle if available
        if relationship == "Cousin" {
            if let auntUncle = allProfiles.first(where: { p in
                p.id != profile.id &&
                (p.relationship == "Aunt" || p.relationship == "Uncle")
            }) {
                return auntUncle.id
            }
            return primaryId
        }

        return nil
    }

    // MARK: - Determine Ring
    /// Determines which ring a profile belongs in based on connection chain depth
    private func determineRing(for profile: Profile, primaryId: UUID, allProfiles: [Profile]) -> Int {
        // Calculate ring based on connection chain depth
        let connectionId = inferConnection(for: profile, primaryId: primaryId, allProfiles: allProfiles)

        // If connected directly to primary, it's ring 1
        if connectionId == primaryId || connectionId == nil {
            // Check relationship-based ring for profiles without explicit connections
            if profile.connectedToProfileId == nil {
                guard let relationship = profile.relationship else { return 1 }

                if Self.grandchildRelationships.contains(relationship) ||
                   Self.niblingRelationships.contains(relationship) ||
                   relationship == "Cousin" {
                    return 2
                }
            }
            return 1
        }

        // Connected to another profile - calculate depth
        let depth = calculateConnectionDepth(for: profile, primaryId: primaryId, allProfiles: allProfiles, visited: Set())
        return depth
    }

    /// Calculates how many connection hops away from primary a profile is
    private func calculateConnectionDepth(for profile: Profile, primaryId: UUID, allProfiles: [Profile], visited: Set<UUID>) -> Int {
        // Prevent infinite loops
        if visited.contains(profile.id) {
            return 1
        }

        var newVisited = visited
        newVisited.insert(profile.id)

        let connectionId = inferConnection(for: profile, primaryId: primaryId, allProfiles: allProfiles)

        // If connected to primary or no connection, depth is 1
        guard let connId = connectionId, connId != primaryId else {
            return 1
        }

        // Find the connected profile and calculate its depth + 1
        if let connectedProfile = allProfiles.first(where: { $0.id == connId }) {
            let parentDepth = calculateConnectionDepth(for: connectedProfile, primaryId: primaryId, allProfiles: allProfiles, visited: newVisited)
            return parentDepth + 1
        }

        return 1
    }

    // MARK: - Build Focused Tree
    /// Builds a tree centered on the focused profile, showing immediate connections (ring 1)
    /// and distant connections (ring 2+) as mini nodes
    private func buildFocusedTree() -> [FamilyTreeNode] {
        var nodes: [FamilyTreeNode] = []

        // Filter profiles to only include those marked for family tree
        let treeProfiles = profiles.filter { $0.includeInFamilyTree }

        guard let focused = focusedProfile ?? primaryProfile else {
            // No focused profile - just arrange all profiles in a circle
            for (index, profile) in treeProfiles.enumerated() {
                let angle = (2 * .pi / Double(max(treeProfiles.count, 1))) * Double(index) - .pi / 2
                let node = FamilyTreeNode(
                    profile: profile,
                    ring: 1,
                    angle: angle,
                    connectedToProfileId: nil
                )
                nodes.append(node)
            }
            return nodes
        }

        // Add focused profile at center (ring 0)
        let focusedNode = FamilyTreeNode(
            profile: focused,
            ring: 0,
            angle: 0,
            connectedToProfileId: nil
        )
        nodes.append(focusedNode)

        var processedIds = Set<UUID>([focused.id])
        var nodeAngles: [UUID: Double] = [focused.id: 0]

        // Find all profiles directly connected TO the focused profile (children/descendants)
        var ring1Profiles: [Profile] = []

        for profile in treeProfiles where profile.id != focused.id {
            // Check if this profile connects to the focused profile
            let connectionId = inferConnectionForFocused(for: profile, focusedId: focused.id, allProfiles: profiles)
            if connectionId == focused.id {
                ring1Profiles.append(profile)
            }
        }

        // Also add the parent of the focused profile (if any) to ring 1
        if let parentId = focused.connectedToProfileId,
           let parent = treeProfiles.first(where: { $0.id == parentId }) {
            if !ring1Profiles.contains(where: { $0.id == parent.id }) {
                ring1Profiles.insert(parent, at: 0)  // Put parent first
            }
        }

        // If focused has explicit connection but parent isn't in ring1, check by relationship
        if let primaryProfile = primaryProfile,
           focused.id != primaryProfile.id,
           !ring1Profiles.contains(where: { $0.id == primaryProfile.id }) {
            // If the focused profile is directly connected to primary, add primary to ring 1
            let focusedConnection = inferConnectionForFocused(for: focused, focusedId: primaryProfile.id, allProfiles: profiles)
            if focusedConnection == primaryProfile.id {
                ring1Profiles.insert(primaryProfile, at: 0)
            }
        }

        // Distribute ring 1 evenly
        let ring1Count = ring1Profiles.count
        for (index, profile) in ring1Profiles.enumerated() {
            let angle = (2 * .pi / Double(max(ring1Count, 1))) * Double(index) - .pi / 2

            let node = FamilyTreeNode(
                profile: profile,
                ring: 1,
                angle: angle,
                connectedToProfileId: focused.id
            )
            nodes.append(node)
            processedIds.insert(profile.id)
            nodeAngles[profile.id] = angle
        }

        // Find ring 2+ profiles (connected to ring 1 profiles)
        var currentRing = 1
        var maxRings = 5  // Limit to prevent infinite loops

        while currentRing < maxRings {
            var nextRingProfiles: [(profile: Profile, parentId: UUID)] = []

            // Get all profiles in the current ring
            let currentRingNodes = nodes.filter { $0.ring == currentRing }

            for ringNode in currentRingNodes {
                // Find profiles connected to this node
                for profile in treeProfiles where !processedIds.contains(profile.id) {
                    let connectionId = inferConnectionForFocused(for: profile, focusedId: focused.id, allProfiles: profiles)
                    if connectionId == ringNode.profile.id {
                        nextRingProfiles.append((profile: profile, parentId: ringNode.profile.id))
                    }
                }
            }

            if nextRingProfiles.isEmpty {
                break
            }

            // Group by parent for proper positioning
            var profilesByParent: [UUID: [Profile]] = [:]
            for item in nextRingProfiles {
                profilesByParent[item.parentId, default: []].append(item.profile)
            }

            // Add profiles with sibling spacing relative to their parent
            for (parentId, siblings) in profilesByParent {
                guard let parentNode = nodes.first(where: { $0.id == parentId }) else { continue }

                let siblingCount = siblings.count
                let spread: Double = 0.4

                for (index, profile) in siblings.sorted(by: { $0.id.uuidString < $1.id.uuidString }).enumerated() {
                    let siblingOffset = (Double(index) - Double(siblingCount - 1) / 2) * spread

                    // Generate deterministic but varied offsets based on profile ID
                    // This creates consistent positioning while preventing overlaps
                    let hashValue = abs(profile.id.hashValue)
                    let radiusHash = Double(hashValue % 1000) / 1000.0  // 0.0 to 1.0
                    let angleHash = Double((hashValue / 1000) % 1000) / 1000.0  // 0.0 to 1.0

                    // Radius variation: -30 to +30 points
                    let radiusOffset = CGFloat((radiusHash - 0.5) * 60)

                    // Angle variation: -0.2 to +0.2 radians (~11 degrees each way)
                    let angleOffset = (angleHash - 0.5) * 0.4

                    let angle = parentNode.angle + siblingOffset + angleOffset

                    let node = FamilyTreeNode(
                        profile: profile,
                        ring: currentRing + 1,
                        angle: angle,
                        connectedToProfileId: parentId,
                        radiusOffset: radiusOffset
                    )
                    nodes.append(node)
                    processedIds.insert(profile.id)
                    nodeAngles[profile.id] = angle
                }
            }

            currentRing += 1
        }

        return nodes
    }

    /// Infer connection relative to the focused profile context
    private func inferConnectionForFocused(for profile: Profile, focusedId: UUID, allProfiles: [Profile]) -> UUID? {
        // If they have an explicit connection, use it
        if let explicitConnection = profile.connectedToProfileId {
            return explicitConnection
        }

        // For primary profile, check standard relationship logic
        guard let primary = primaryProfile else { return nil }

        // Use the existing infer logic relative to primary
        let result = inferConnection(for: profile, primaryId: primary.id, allProfiles: allProfiles)

        // If no connection was inferred (e.g. synced/connected profiles with no relationship set),
        // default to connecting to the primary profile so they still appear in the tree
        if result == nil {
            return primary.id
        }

        return result
    }

    // MARK: - Build Family Tree (Legacy)
    private func buildFamilyTree() -> [FamilyTreeNode] {
        var nodes: [FamilyTreeNode] = []
        var processedIds = Set<UUID>()
        var nodeAngles: [UUID: Double] = [:]

        // Filter profiles to only include those marked for family tree
        let treeProfiles = profiles.filter { $0.includeInFamilyTree }

        // Start with primary profile at center (ring 0)
        guard let primary = primaryProfile, primary.includeInFamilyTree else {
            // No primary profile - just arrange all profiles in a circle
            for (index, profile) in treeProfiles.enumerated() {
                let angle = (2 * .pi / Double(max(treeProfiles.count, 1))) * Double(index) - .pi / 2
                let node = FamilyTreeNode(
                    profile: profile,
                    ring: 1,
                    angle: angle,
                    connectedToProfileId: nil
                )
                nodes.append(node)
            }
            return nodes
        }

        // Add primary at center
        let primaryNode = FamilyTreeNode(
            profile: primary,
            ring: 0,
            angle: 0,
            connectedToProfileId: nil
        )
        nodes.append(primaryNode)
        processedIds.insert(primary.id)
        nodeAngles[primary.id] = 0

        // Group all non-primary profiles by their ring level
        var profilesByRing: [Int: [Profile]] = [:]

        for profile in treeProfiles where profile.id != primary.id {
            let ring = determineRing(for: profile, primaryId: primary.id, allProfiles: profiles)
            profilesByRing[ring, default: []].append(profile)
        }

        // Process rings in order (1, 2, 3, ...)
        let maxRing = profilesByRing.keys.max() ?? 1

        for ringLevel in 1...maxRing {
            guard let ringProfiles = profilesByRing[ringLevel] else { continue }

            // Pre-calculate connections for this ring's profiles
            var ringConnections: [UUID: UUID] = [:]
            for profile in ringProfiles {
                let connectionId = inferConnection(for: profile, primaryId: primary.id, allProfiles: profiles)
                if let connId = connectionId {
                    ringConnections[profile.id] = connId
                }
            }

            // Special handling for ring 1: distribute evenly around the circle
            if ringLevel == 1 {
                let ring1Count = ringProfiles.count
                for (index, profile) in ringProfiles.enumerated() {
                    let angle = (2 * .pi / Double(max(ring1Count, 1))) * Double(index) - .pi / 2

                    let node = FamilyTreeNode(
                        profile: profile,
                        ring: 1,
                        angle: angle,
                        connectedToProfileId: primary.id
                    )
                    nodes.append(node)
                    processedIds.insert(profile.id)
                    nodeAngles[profile.id] = angle
                }
                continue
            }

            // For ring 2+: Group profiles by their parent
            var profilesByParent: [UUID: [Profile]] = [:]
            var orphanProfiles: [Profile] = []

            for profile in ringProfiles {
                if let parentId = ringConnections[profile.id],
                   nodes.contains(where: { $0.id == parentId }) {
                    profilesByParent[parentId, default: []].append(profile)
                } else {
                    orphanProfiles.append(profile)
                }
            }

            // Add profiles grouped by parent, with proper sibling spacing
            for (parentId, siblings) in profilesByParent {
                guard let parentNode = nodes.first(where: { $0.id == parentId }) else { continue }

                let siblingCount = siblings.count
                let spread: Double = 0.4

                for (index, profile) in siblings.sorted(by: { $0.id.uuidString < $1.id.uuidString }).enumerated() {
                    let siblingOffset = (Double(index) - Double(siblingCount - 1) / 2) * spread
                    let angle = parentNode.angle + siblingOffset

                    let node = FamilyTreeNode(
                        profile: profile,
                        ring: ringLevel,
                        angle: angle,
                        connectedToProfileId: parentId
                    )
                    nodes.append(node)
                    processedIds.insert(profile.id)
                    nodeAngles[profile.id] = angle
                }
            }

            // Add orphan profiles (no valid parent found) evenly distributed
            if !orphanProfiles.isEmpty {
                for (index, profile) in orphanProfiles.enumerated() {
                    let angle = (2 * .pi / Double(orphanProfiles.count)) * Double(index) - .pi / 2

                    let node = FamilyTreeNode(
                        profile: profile,
                        ring: ringLevel,
                        angle: angle,
                        connectedToProfileId: ringConnections[profile.id]
                    )
                    nodes.append(node)
                    processedIds.insert(profile.id)
                    nodeAngles[profile.id] = angle
                }
            }
        }

        return nodes
    }

    // MARK: - Node Position
    private func nodePosition(for node: FamilyTreeNode, center: CGPoint, containerSize: CGSize) -> CGPoint {
        // Distance from center to first ring
        let firstRingRadius: CGFloat = isIPad ? 140 : 130
        // Distance between subsequent rings
        let ringSpacing: CGFloat = isIPad ? 120 : 110

        var radius: CGFloat
        if node.ring == 0 {
            radius = 0
        } else if node.ring == 1 {
            radius = firstRingRadius
        } else {
            // For ring 2+, apply the random offset to vary line lengths
            radius = firstRingRadius + ringSpacing * CGFloat(node.ring - 1) + node.radiusOffset
        }

        let x = center.x + radius * cos(node.angle)
        let y = center.y + radius * sin(node.angle)

        return CGPoint(x: x, y: y)
    }

    /// Returns the center point of the circle within a node (accounting for text labels below)
    private func nodeCircleCenter(for node: FamilyTreeNode, center: CGPoint, containerSize: CGSize, isMini: Bool = false) -> CGPoint {
        let position = nodePosition(for: node, center: center, containerSize: containerSize)

        // Mini nodes are just circles with no text, so no offset needed
        if isMini {
            return position
        }

        let isFocused = node.ring == 0
        let nodeSize: CGFloat = isFocused ? 90 : 70

        // The VStack has: circle (nodeSize) + spacing (4) + name text (~16) + spacing + relationship (~12)
        // Total text height is approximately 30-35 points below the circle
        // The .position() centers the entire VStack, so the circle is offset upward
        // Calculate offset: half of (name height + relationship height + spacings)
        let textOffset: CGFloat = 18  // Approximate offset to move from VStack center to circle center

        return CGPoint(x: position.x, y: position.y - textOffset)
    }
}

// MARK: - Family Tree Node
struct FamilyTreeNode: Identifiable {
    let id: UUID  // Use the profile's ID for consistency
    let profile: Profile
    let ring: Int  // 0 = center (primary), 1 = first ring, 2 = second ring, etc.
    let angle: Double  // Position angle in radians
    var connectedToProfileId: UUID?  // Reference by ID instead of direct reference
    var radiusOffset: CGFloat  // Random offset for ring 2+ to prevent overlapping

    init(profile: Profile, ring: Int, angle: Double, connectedToProfileId: UUID? = nil, radiusOffset: CGFloat = 0) {
        self.id = profile.id
        self.profile = profile
        self.ring = ring
        self.angle = angle
        self.connectedToProfileId = connectedToProfileId
        self.radiusOffset = radiusOffset
    }
}

// MARK: - Family Tree Node View
struct FamilyTreeNodeView: View {
    let node: FamilyTreeNode
    let isSelected: Bool
    let isFocused: Bool  // Whether this node is at the center (ring 0)
    let accentColor: Color

    @Environment(\.appAccentColor) private var appAccentColor
    @State private var pulseScale: CGFloat = 1.0
    @State private var glowOpacity: Double = 0.0

    private var nodeSize: CGFloat {
        isFocused ? 90 : 70
    }

    var body: some View {
        VStack(spacing: 4) {
            // Profile photo or initials
            ZStack {
                // Animated glow ring for selected state
                if isSelected {
                    Circle()
                        .fill(accentColor.opacity(0.3))
                        .frame(width: nodeSize + 20, height: nodeSize + 20)
                        .scaleEffect(pulseScale)
                        .opacity(glowOpacity)

                    Circle()
                        .fill(accentColor.opacity(0.15))
                        .frame(width: nodeSize + 35, height: nodeSize + 35)
                        .scaleEffect(pulseScale)
                        .opacity(glowOpacity * 0.6)
                }

                Circle()
                    .fill(isFocused ? accentColor : Color.cardBackground)
                    .frame(width: nodeSize, height: nodeSize)
                    .shadow(color: isSelected ? accentColor.opacity(0.6) : .black.opacity(0.2),
                            radius: isSelected ? 15 : 5)

                if let photoUrl = node.profile.photoUrl, let url = URL(string: photoUrl) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        initialsView
                    }
                    .frame(width: nodeSize - 4, height: nodeSize - 4)
                    .clipShape(Circle())
                } else {
                    initialsView
                }

                // Selection ring with animation
                if isSelected {
                    Circle()
                        .stroke(accentColor, lineWidth: 3)
                        .frame(width: nodeSize + 6, height: nodeSize + 6)
                        .scaleEffect(isSelected ? 1.0 : 0.8)
                }
            }
            .scaleEffect(isSelected ? 1.1 : 1.0)
            .animation(.spring(response: 0.4, dampingFraction: 0.6), value: isSelected)

            // Name
            Text(node.profile.displayName)
                .font(.system(size: isFocused ? 14 : 12, weight: isSelected ? .bold : .medium))
                .foregroundColor(isSelected ? accentColor : .textPrimary)
                .lineLimit(1)
                .animation(.easeInOut(duration: 0.2), value: isSelected)

            // Relationship
            if let relationship = node.profile.relationship {
                Text(relationship)
                    .font(.system(size: 10))
                    .foregroundColor(.textSecondary)
                    .lineLimit(1)
            }
        }
        .frame(width: nodeSize + 40)
        .onChange(of: isSelected) { _, newValue in
            if newValue {
                // Start pulse animation when selected
                startPulseAnimation()
            } else {
                // Reset animation values
                pulseScale = 1.0
                glowOpacity = 0.0
            }
        }
    }

    private func startPulseAnimation() {
        // Initial pulse
        withAnimation(.easeOut(duration: 0.3)) {
            pulseScale = 1.2
            glowOpacity = 0.8
        }

        // Settle to gentle breathing animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(
                .easeInOut(duration: 1.5)
                .repeatForever(autoreverses: true)
            ) {
                pulseScale = 1.1
                glowOpacity = 0.5
            }
        }
    }

    private var initialsView: some View {
        Text(node.profile.displayName.initials)
            .font(.system(size: isFocused ? 28 : 20, weight: .semibold))
            .foregroundColor(isFocused ? .black : .textPrimary)
    }
}

// MARK: - Mini Node View
/// A simplified node view for ring 2+ profiles - just a small dot with minimal info on tap
struct MiniNodeView: View {
    let node: FamilyTreeNode
    let accentColor: Color

    private let nodeSize: CGFloat = 24

    var body: some View {
        ZStack {
            // Outer ring
            Circle()
                .stroke(accentColor.opacity(0.4), lineWidth: 2)
                .frame(width: nodeSize + 4, height: nodeSize + 4)

            // Main circle
            Circle()
                .fill(Color.cardBackground)
                .frame(width: nodeSize, height: nodeSize)
                .shadow(color: .black.opacity(0.2), radius: 3)

            // Photo or initials
            if let photoUrl = node.profile.photoUrl, let url = URL(string: photoUrl) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Text(node.profile.displayName.initials)
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.textPrimary)
                }
                .frame(width: nodeSize - 2, height: nodeSize - 2)
                .clipShape(Circle())
            } else {
                Text(node.profile.displayName.initials)
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.textPrimary)
            }
        }
        .frame(width: nodeSize + 10, height: nodeSize + 10)
    }
}

// MARK: - Connection Line
struct ConnectionLine: View {
    let from: CGPoint
    let to: CGPoint
    let color: Color

    var body: some View {
        Path { path in
            path.move(to: from)
            path.addLine(to: to)
        }
        .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round))
    }
}

// MARK: - Profile Detail Card
struct ProfileDetailCard: View {
    let profile: Profile
    let connectedToProfile: Profile?
    let onClose: () -> Void

    @Environment(\.appAccentColor) private var appAccentColor
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var isIPad: Bool {
        horizontalSizeClass == .regular
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    // Name with navigation link
                    NavigationLink {
                        ProfileDetailView(profile: profile)
                    } label: {
                        HStack(spacing: 6) {
                            Text(profile.displayName)
                                .font(.appTitle)
                                .foregroundColor(.textPrimary)

                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.textSecondary)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())

                    if let relationship = profile.relationship {
                        Text(relationship)
                            .font(.appBody)
                            .foregroundColor(appAccentColor)
                    }
                }

                Spacer()

                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.textSecondary)
                }
            }

            Divider()

            // Connection info
            if let connected = connectedToProfile {
                HStack(spacing: 8) {
                    Image(systemName: "link")
                        .foregroundColor(.textSecondary)

                    Text("Connected to \(connected.displayName)")
                        .font(.appCaption)
                        .foregroundColor(.textSecondary)

                    if let connectedRelationship = connected.relationship {
                        Text("(\(connectedRelationship))")
                            .font(.appCaption)
                            .foregroundColor(.textSecondary.opacity(0.7))
                    }
                }
            }

            // Contact info
            if let phone = profile.phone {
                HStack(spacing: 8) {
                    Image(systemName: "phone")
                        .foregroundColor(.textSecondary)
                    Text(phone)
                        .font(.appCaption)
                        .foregroundColor(.textPrimary)
                }
            }

            if let birthday = profile.birthday {
                HStack(spacing: 8) {
                    Image(systemName: "gift")
                        .foregroundColor(.textSecondary)
                    Text(birthday.formattedBirthday())
                        .font(.appCaption)
                        .foregroundColor(.textPrimary)

                    if let age = profile.age {
                        Text("(\(age) years old)")
                            .font(.appCaption)
                            .foregroundColor(.textSecondary)
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: isIPad ? 400 : .infinity)
        .background(Color.cardBackground)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.2), radius: 10)
    }
}

// MARK: - String Extension for Initials
private extension String {
    var initials: String {
        let words = self.split(separator: " ")
        let initials = words.prefix(2).compactMap { $0.first }.map { String($0).uppercased() }
        return initials.joined()
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        FamilyTreeView()
            .environmentObject(AppState.forPreview())
    }
}
