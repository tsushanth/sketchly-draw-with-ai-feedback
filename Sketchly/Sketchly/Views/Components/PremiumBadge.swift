//
//  PremiumBadge.swift
//  Sketchly
//

import SwiftUI

struct PremiumBadge: View {
    var style: Style = .standard

    enum Style {
        case standard
        case compact
        case icon
    }

    var body: some View {
        switch style {
        case .standard:
            HStack(spacing: 4) {
                Image(systemName: "crown.fill")
                    .font(.caption2)
                Text("PREMIUM")
                    .font(.caption2)
                    .fontWeight(.bold)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                LinearGradient(
                    colors: [.orange, .pink],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(Capsule())

        case .compact:
            Image(systemName: "crown.fill")
                .font(.caption)
                .foregroundStyle(
                    LinearGradient(
                        colors: [.orange, .pink],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

        case .icon:
            Image(systemName: "lock.fill")
                .font(.caption)
                .foregroundColor(.white)
                .padding(6)
                .background(
                    LinearGradient(
                        colors: [.orange, .pink],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(Circle())
        }
    }
}
