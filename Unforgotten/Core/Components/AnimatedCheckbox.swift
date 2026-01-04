//
//  AnimatedCheckbox.swift
//  Unforgotten
//
//  Created on 2025-12-18
//

import SwiftUI

struct AnimatedCheckbox: View {
    @Binding var isChecked: Bool
    let onToggle: () -> Void
    @Environment(\.appAccentColor) private var appAccentColor

    @State private var scale: CGFloat = 1.0
    @State private var checkmarkOpacity: Double = 0

    private let size: CGFloat = 24
    private let cornerRadius: CGFloat = 6

    var body: some View {
        Button(action: toggle) {
            ZStack {
                // Border/Background
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(isChecked ? appAccentColor : Color.textSecondary.opacity(0.5), lineWidth: 2)
                    .frame(width: size, height: size)

                // Fill when checked
                RoundedRectangle(cornerRadius: cornerRadius - 1)
                    .fill(isChecked ? appAccentColor : Color.clear)
                    .frame(width: size - 4, height: size - 4)

                // Checkmark
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .opacity(checkmarkOpacity)
            }
            .scaleEffect(scale)
        }
        .buttonStyle(PlainButtonStyle())
        .onAppear {
            checkmarkOpacity = isChecked ? 1 : 0
        }
    }

    private func toggle() {
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()

        // Call onToggle immediately to update the parent state
        onToggle()

        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            scale = 0.8
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                scale = 1.1
                checkmarkOpacity = isChecked ? 1 : 0
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                scale = 1.0
            }
        }
    }
}
