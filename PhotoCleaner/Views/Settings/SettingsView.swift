import SwiftUI
import StoreKit
import UIKit

struct SettingsView: View {
    @EnvironmentObject var vm: ScanViewModel
    @AppStorage("themeMode") private var themeModeRaw = AppThemeMode.system.rawValue
    @AppStorage("appLanguage") private var appLanguageRaw = AppLanguage.zh.rawValue
    @AppStorage("autoSelect")   private var autoSelect   = true
    @AppStorage("protectFaces") private var protectFaces = true
    @AppStorage("deleteThreshold") private var threshold = 40
    @State private var showThresholdPicker = false
    @State private var stats: DatabaseService.CleaningStats = .zero
    @State private var showRescanConfirm = false
    @State private var showPrivacySheet = false

    private var currentThemeMode: AppThemeMode {
        AppThemeMode(rawValue: themeModeRaw) ?? .system
    }
    private var currentLanguage: AppLanguage {
        AppLanguage(rawValue: appLanguageRaw) ?? .zh
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.darkBG.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 0) {
                        // Title
                        HStack {
                            Text(L10n.tabMe)
                                .font(AppTypography.hero)
                                .foregroundColor(AppColors.textPrimary)
                            Spacer()
                        }
                        .padding(.horizontal)
                        .padding(.top, 16)
                        .padding(.bottom, 12)

                        // Hero: achievements card
                        AchievementHeroCard(stats: stats)
                            .padding(.horizontal)
                            .padding(.bottom, 4)

                        // Section: 清理设置
                        SettingsSectionHeader(title: L10n.cleanSettings)

                        settingsGroup {
                            Button {
                                showThresholdPicker.toggle()
                            } label: {
                                HStack(spacing: 12) {
                                    iconBox("target", bg: AppColors.purple)
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(L10n.deleteThreshold).foregroundColor(AppColors.textPrimary).font(AppTypography.body)
                                        Text(L10n.thresholdDesc(threshold)).foregroundColor(AppColors.textTertiary).font(.caption)
                                    }
                                    Spacer()
                                    Text("\(threshold)").foregroundColor(AppColors.textTertiary).font(.subheadline)
                                    Image(systemName: "chevron.right").font(.caption).foregroundColor(AppColors.textTertiary)
                                }
                                .padding(.horizontal).padding(.vertical, 10)
                            }

                            Divider().background(AppColors.separator).padding(.leading, 52)

                            SettingsToggleRow(icon: "arrow.triangle.2.circlepath", iconBg: AppColors.green,
                                              title: L10n.autoSelect, subtitle: L10n.autoSelectDesc,
                                              isOn: $autoSelect)
                            Divider().background(AppColors.separator).padding(.leading, 52)

                            SettingsToggleRow(icon: "shield.fill", iconBg: AppColors.red,
                                              title: L10n.protectFace, subtitle: L10n.protectFaceDesc,
                                              isOn: $protectFaces)
                        }

                        if showThresholdPicker {
                            VStack(spacing: 8) {
                                HStack {
                                    Text(L10n.currentThreshold(threshold)).font(AppTypography.body).foregroundColor(AppColors.textPrimary)
                                    Spacer()
                                }
                                Slider(value: Binding(get: { Double(threshold) }, set: { threshold = Int($0) }),
                                       in: 10...80, step: 1)
                                    .tint(AppColors.purple)
                                HStack {
                                    Text(L10n.lenient).font(.caption).foregroundColor(AppColors.textSecondary)
                                    Spacer()
                                    Text(L10n.strict).font(.caption).foregroundColor(AppColors.textSecondary)
                                }
                            }
                            .padding()
                            .appleCardStyle()
                            .padding(.horizontal)
                            .padding(.top, 4)
                        }

                        // Section: 外观
                        SettingsSectionHeader(title: L10n.appearance)

                        settingsGroup {
                            NavigationLink {
                                ThemeModeSelectionView(themeModeRaw: $themeModeRaw)
                            } label: {
                                HStack(spacing: 12) {
                                    iconBox("circle.lefthalf.filled", bg: AppColors.blue)
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(L10n.displayMode).foregroundColor(AppColors.textPrimary).font(AppTypography.body)
                                        Text(L10n.followSystem).foregroundColor(AppColors.textTertiary).font(AppTypography.caption)
                                    }
                                    Spacer()
                                    Text(currentThemeMode.title).foregroundColor(AppColors.textSecondary).font(AppTypography.caption)
                                    Image(systemName: "chevron.right").font(.caption).foregroundColor(AppColors.textTertiary)
                                }
                                .padding(.horizontal).padding(.vertical, 10)
                            }
                            .buttonStyle(.plain)

                            Divider().background(AppColors.separator).padding(.leading, 52)

                            NavigationLink {
                                LanguageSelectionView(appLanguageRaw: $appLanguageRaw)
                            } label: {
                                HStack(spacing: 12) {
                                    iconBox("globe", bg: AppColors.green)
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(L10n.language).foregroundColor(AppColors.textPrimary).font(AppTypography.body)
                                        Text(L10n.languageSubtitle).foregroundColor(AppColors.textTertiary).font(AppTypography.caption)
                                    }
                                    Spacer()
                                    Text(currentLanguage.displayName).foregroundColor(AppColors.textSecondary).font(AppTypography.caption)
                                    Image(systemName: "chevron.right").font(.caption).foregroundColor(AppColors.textTertiary)
                                }
                                .padding(.horizontal).padding(.vertical, 10)
                            }
                            .buttonStyle(.plain)
                        }

                        // Section: 数据管理
                        SettingsSectionHeader(title: L10n.dataManagement)

                        settingsGroup {
                            Button {
                                openRecentlyDeleted()
                            } label: {
                                rowContent(icon: "trash.circle.fill", iconBg: AppColors.amber,
                                           title: L10n.recentlyDeleted, subtitle: L10n.recentlyDeletedDesc,
                                           trailing: "arrow.up.right")
                            }
                            .buttonStyle(.plain)

                            Divider().background(AppColors.separator).padding(.leading, 52)

                            Button {
                                showRescanConfirm = true
                            } label: {
                                rowContent(icon: "arrow.clockwise", iconBg: AppColors.blue,
                                           title: L10n.rescanLibrary, subtitle: L10n.rescanLibraryDesc,
                                           trailing: "chevron.right")
                            }
                            .buttonStyle(.plain)
                        }

                        // Section: 关于
                        SettingsSectionHeader(title: L10n.aboutSection)

                        settingsGroup {
                            Button {
                                sendFeedback()
                            } label: {
                                rowContent(icon: "envelope.fill", iconBg: AppColors.purple,
                                           title: L10n.feedback, subtitle: L10n.feedbackDesc,
                                           trailing: "arrow.up.right")
                            }
                            .buttonStyle(.plain)

                            Divider().background(AppColors.separator).padding(.leading, 52)

                            Button {
                                requestRating()
                            } label: {
                                rowContent(icon: "star.fill", iconBg: AppColors.amber,
                                           title: L10n.rateApp, subtitle: L10n.rateAppDesc,
                                           trailing: "chevron.right")
                            }
                            .buttonStyle(.plain)

                            Divider().background(AppColors.separator).padding(.leading, 52)

                            Button {
                                showPrivacySheet = true
                            } label: {
                                rowContent(icon: "lock.shield.fill", iconBg: AppColors.green,
                                           title: L10n.privacyPolicy, subtitle: L10n.privacyPolicyDesc,
                                           trailing: "chevron.right")
                            }
                            .buttonStyle(.plain)
                        }

                        // Version
                        Text(L10n.isEn ? "Lighten v1.0.0" : "轻相册 v1.0.0")
                            .font(.caption).foregroundColor(AppColors.textTertiary)
                            .padding(.top, 24).padding(.bottom, 16)
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .task { stats = await DatabaseService.shared.loadCleaningStats() }
            .confirmationDialog(L10n.rescanConfirmTitle,
                                isPresented: $showRescanConfirm,
                                titleVisibility: .visible) {
                Button(L10n.rescanAction, role: .destructive) {
                    vm.reset()
                    vm.startScan()
                }
                Button(L10n.cancel, role: .cancel) {}
            } message: {
                Text(L10n.rescanConfirmMessage)
            }
            .sheet(isPresented: $showPrivacySheet) {
                PrivacyPolicySheet()
            }
        }
    }

    // MARK: - Actions

    private func openRecentlyDeleted() {
        guard let url = URL(string: "photos-redirect://") else { return }
        UIApplication.shared.open(url)
    }

    private func sendFeedback() {
        let subject = "Lighten Feedback"
        let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? subject
        guard let url = URL(string: "mailto:danny.wangle@gmail.com?subject=\(encodedSubject)") else { return }
        UIApplication.shared.open(url)
    }

    private func requestRating() {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }) ?? UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first
        else { return }
        SKStoreReviewController.requestReview(in: scene)
    }

    // MARK: - Builders

    @ViewBuilder
    func settingsGroup<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) {
            content()
        }
        .background(AppColors.deepCard)
        .cornerRadius(AppShape.cardRadius)
        .overlay(
            RoundedRectangle(cornerRadius: AppShape.cardRadius)
                .stroke(AppColors.subtleBorder, lineWidth: AppShape.borderWidth)
        )
        .padding(.horizontal)
        .padding(.bottom, 4)
    }

    func iconBox(_ name: String, bg: Color) -> some View {
        Image(systemName: name).font(.system(size: 14))
            .frame(width: 30, height: 30).background(bg).foregroundColor(.white).cornerRadius(AppShape.iconRadius)
    }

    @ViewBuilder
    func rowContent(icon: String, iconBg: Color, title: String, subtitle: String, trailing: String) -> some View {
        HStack(spacing: 12) {
            iconBox(icon, bg: iconBg)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).foregroundColor(AppColors.textPrimary).font(AppTypography.body)
                Text(subtitle).foregroundColor(AppColors.textTertiary).font(.caption)
            }
            Spacer()
            Image(systemName: trailing).font(.caption).foregroundColor(AppColors.textTertiary)
        }
        .padding(.horizontal).padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}

// MARK: - Achievement Hero Card

private struct AchievementHeroCard: View {
    let stats: DatabaseService.CleaningStats

    private var freedString: String {
        ByteCountFormatter.string(fromByteCount: stats.freedBytes, countStyle: .file)
    }
    private var cleanupsString: String {
        "\(stats.scanCount)"
    }
    private var healthString: String {
        if stats.healthGain > 0 { return "+\(stats.healthGain)" }
        if stats.scanCount > 0 { return "—" }
        return "—"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L10n.myAchievementsTitle)
                .font(AppTypography.caption.weight(.semibold))
                .foregroundColor(AppColors.textSecondary)
                .textCase(.uppercase)

            HStack(alignment: .top, spacing: 0) {
                statCell(value: freedString, label: L10n.freedShort, color: AppColors.red)
                Divider().frame(height: 36).background(AppColors.separator)
                statCell(value: cleanupsString, label: L10n.cleanupsShort, color: AppColors.green)
                Divider().frame(height: 36).background(AppColors.separator)
                statCell(value: healthString, label: L10n.healthShort, color: AppColors.amber)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.deepCard)
        .cornerRadius(AppShape.cardRadius)
        .overlay(
            RoundedRectangle(cornerRadius: AppShape.cardRadius)
                .stroke(AppColors.subtleBorder, lineWidth: AppShape.borderWidth)
        )
    }

    private func statCell(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.caption)
                .foregroundColor(AppColors.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Privacy Sheet

private struct PrivacyPolicySheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.darkBG.ignoresSafeArea()
                ScrollView {
                    Text(L10n.privacyPolicyBody)
                        .font(AppTypography.body)
                        .foregroundColor(AppColors.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                }
            }
            .navigationTitle(L10n.privacyPolicy)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.done) { dismiss() }
                        .foregroundColor(AppColors.lightPurple)
                }
            }
        }
    }
}

struct SettingsSectionHeader: View {
    let title: String
    var body: some View {
        Text(title)
            .font(AppTypography.micro.weight(.semibold))
            .foregroundColor(AppColors.textTertiary)
            .textCase(.uppercase)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
            .padding(.top, 20).padding(.bottom, 7)
    }
}

private struct ThemeModeSelectionView: View {
    @Binding var themeModeRaw: String

    private var currentThemeMode: AppThemeMode {
        AppThemeMode(rawValue: themeModeRaw) ?? .system
    }

    var body: some View {
        ZStack {
            AppColors.darkBG.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(Array(AppThemeMode.allCases.enumerated()), id: \.element.id) { index, mode in
                        Button {
                            themeModeRaw = mode.rawValue
                        } label: {
                            HStack {
                                Text(mode.title)
                                    .foregroundColor(AppColors.textPrimary)
                                Spacer()
                                if mode == currentThemeMode {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(AppColors.lightPurple)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 14)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        if index < AppThemeMode.allCases.count - 1 {
                            Divider()
                                .background(AppColors.separator)
                                .padding(.leading, 14)
                        }
                    }
                }
                .background(AppColors.deepCard)
                .cornerRadius(AppShape.cardRadius)
                .overlay(
                    RoundedRectangle(cornerRadius: AppShape.cardRadius)
                        .stroke(AppColors.subtleBorder, lineWidth: AppShape.borderWidth)
                )
                .padding(.horizontal)
                .padding(.top, 14)
            }
        }
        .navigationTitle(L10n.displayMode)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
    }
}

private struct LanguageSelectionView: View {
    @Binding var appLanguageRaw: String

    private var currentLanguage: AppLanguage {
        AppLanguage(rawValue: appLanguageRaw) ?? .zh
    }

    var body: some View {
        ZStack {
            AppColors.darkBG.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(Array(AppLanguage.allCases.enumerated()), id: \.element.id) { index, lang in
                        Button {
                            appLanguageRaw = lang.rawValue
                        } label: {
                            HStack {
                                Text(lang.displayName)
                                    .foregroundColor(AppColors.textPrimary)
                                Spacer()
                                if lang == currentLanguage {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(AppColors.lightPurple)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 14)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        if index < AppLanguage.allCases.count - 1 {
                            Divider()
                                .background(AppColors.separator)
                                .padding(.leading, 14)
                        }
                    }
                }
                .background(AppColors.deepCard)
                .cornerRadius(AppShape.cardRadius)
                .overlay(
                    RoundedRectangle(cornerRadius: AppShape.cardRadius)
                        .stroke(AppColors.subtleBorder, lineWidth: AppShape.borderWidth)
                )
                .padding(.horizontal)
                .padding(.top, 14)
            }
        }
        .navigationTitle(L10n.language)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
    }
}
