import SwiftUI

// MARK: - OnboardingHero
/// Shared layout for the top 60% of every onboarding page:
/// blue radial halo → hero slot → title → description, with synchronised
/// entrance animation (hero scale-fade, text slide-fade).
struct OnboardingHero<Hero: View>: View {
    let title: String
    let desc: String
    let haloDiameter: CGFloat
    @ViewBuilder let hero: () -> Hero
    @State private var animateIn = false

    init(
        title: String,
        desc: String,
        haloDiameter: CGFloat = 240,
        @ViewBuilder hero: @escaping () -> Hero
    ) {
        self.title = title
        self.desc = desc
        self.haloDiameter = haloDiameter
        self.hero = hero
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 20)

            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                AppColors.purple.opacity(0.32),
                                AppColors.purple.opacity(0.02)
                            ],
                            center: .init(x: 0.5, y: 0.4),
                            startRadius: 0,
                            endRadius: haloDiameter * 0.55
                        )
                    )
                    .frame(width: haloDiameter, height: haloDiameter)
                    .blur(radius: 4)

                hero()
            }
            .scaleEffect(animateIn ? 1.0 : 0.85)
            .opacity(animateIn ? 1.0 : 0.0)

            Spacer().frame(height: 28)

            VStack(spacing: 10) {
                Text(title)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Text(desc)
                    .font(.system(size: 15))
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 32)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .offset(y: animateIn ? 0 : 30)
            .opacity(animateIn ? 1.0 : 0.0)

            Spacer()
            // Reserved area for OnboardingBottomBar
            Spacer().frame(height: 120)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6).delay(0.15)) {
                animateIn = true
            }
        }
    }
}

// MARK: - GradientIcon
/// 80×80 rounded blue gradient block with an inset SF Symbol.
/// Used as the hero for permission / informational pages.
struct GradientIcon: View {
    let systemName: String

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [AppColors.purple, AppColors.lightPurple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 80, height: 80)
                .shadow(color: AppColors.purple.opacity(0.4), radius: 24, y: 10)

            Image(systemName: systemName)
                .font(.system(size: 36, weight: .medium))
                .foregroundColor(.white)
        }
    }
}

// MARK: - OnboardingBottomBar
/// Bottom controls. Page indicator stays left-aligned on every page.
/// When `primaryWide` is true (permission / scan pages), the primary CTA is a
/// full-width pill rendered above the indicator row, with an optional
/// secondary "skip" text link beneath it.
struct OnboardingBottomBar: View {
    let currentPage: Int
    let totalPages: Int
    let primaryTitle: String?
    let primaryIcon: String?      // SF Symbol shown left of the title (wide layout)
    let primaryWide: Bool
    let primaryDisabled: Bool
    let onPrimary: () -> Void
    let secondaryTitle: String?
    let onSecondary: (() -> Void)?

    init(
        currentPage: Int,
        totalPages: Int,
        primaryTitle: String? = nil,
        primaryIcon: String? = nil,
        primaryWide: Bool = false,
        primaryDisabled: Bool = false,
        onPrimary: @escaping () -> Void = {},
        secondaryTitle: String? = nil,
        onSecondary: (() -> Void)? = nil
    ) {
        self.currentPage = currentPage
        self.totalPages = totalPages
        self.primaryTitle = primaryTitle
        self.primaryIcon = primaryIcon
        self.primaryWide = primaryWide
        self.primaryDisabled = primaryDisabled
        self.onPrimary = onPrimary
        self.secondaryTitle = secondaryTitle
        self.onSecondary = onSecondary
    }

    var body: some View {
        VStack(spacing: 12) {
            if primaryWide, let title = primaryTitle {
                Button(action: onPrimary) {
                    HStack(spacing: 6) {
                        if let icon = primaryIcon {
                            Image(systemName: icon)
                        }
                        Text(title)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(ApplePrimaryButtonStyle())
                .disabled(primaryDisabled)
                .padding(.horizontal, 28)

                if let sTitle = secondaryTitle, let onS = onSecondary {
                    Button(action: onS) {
                        Text(sTitle)
                            .font(.system(size: 15))
                            .foregroundColor(AppColors.textTertiary)
                    }
                }
            }

            HStack {
                HStack(spacing: 4) {
                    ForEach(0..<totalPages, id: \.self) { i in
                        Capsule()
                            .fill(i == currentPage ? AppColors.purple : AppColors.textTertiary.opacity(0.4))
                            .frame(width: i == currentPage ? 14 : 4, height: 4)
                            .animation(.easeInOut(duration: 0.25), value: currentPage)
                    }
                }
                Spacer()
                if !primaryWide, let title = primaryTitle {
                    Button(action: onPrimary) {
                        HStack(spacing: 4) {
                            Text(title)
                            Image(systemName: "arrow.right")
                                .font(.system(size: 14, weight: .semibold))
                        }
                    }
                    .buttonStyle(ApplePrimaryButtonStyle())
                }
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 36)
        }
    }
}
