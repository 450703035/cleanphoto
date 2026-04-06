import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var vm: ScanViewModel
    @AppStorage("themeMode") private var themeModeRaw = AppThemeMode.system.rawValue
    @AppStorage("autoSelect")   private var autoSelect   = true
    @AppStorage("timeWeight")   private var timeWeight   = true
    @AppStorage("protectFaces") private var protectFaces = true
    @AppStorage("dailyReminder") private var dailyReminder = false
    @AppStorage("deleteThreshold") private var threshold = 40
    @State private var showThresholdPicker = false
    @State private var stats: DatabaseService.CleaningStats = .zero
    private var currentThemeMode: AppThemeMode {
        AppThemeMode(rawValue: themeModeRaw) ?? .system
    }

    var body: some View {
        ZStack {
            AppColors.darkBG.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 0) {
                    // User header
                    HStack(spacing: 14) {
                        Circle()
                            .fill(AppColors.deepCard)
                            .frame(width: 52, height: 52)
                            .overlay(Image(systemName: "person.fill").font(.title3).foregroundColor(.white))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(L10n.userAccount).font(AppTypography.body.weight(.semibold)).foregroundColor(AppColors.textPrimary)
                            Text(L10n.freeVersion).font(AppTypography.caption).foregroundColor(AppColors.textSecondary)
                        }
                        Spacer()
                        Button(L10n.upgradePro) {}
                            .buttonStyle(ApplePrimaryButtonStyle())
                    }
                    .padding()

                    SettingsSectionHeader(title: L10n.appearance)

                    settingsGroup {
                        Menu {
                            ForEach(AppThemeMode.allCases) { mode in
                                Button(mode.title) { themeModeRaw = mode.rawValue }
                            }
                        } label: {
                            HStack(spacing: 12) {
                                iconBox("circle.lefthalf.filled", bg: AppColors.blue)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(L10n.displayMode).foregroundColor(AppColors.textPrimary).font(AppTypography.body)
                                    Text(L10n.followSystem).foregroundColor(AppColors.textTertiary).font(AppTypography.caption)
                                }
                                Spacer()
                                Text(currentThemeMode.title).foregroundColor(AppColors.textSecondary).font(AppTypography.caption)
                                Image(systemName: "chevron.up.chevron.down").font(.caption2).foregroundColor(AppColors.textTertiary)
                            }
                            .padding(.horizontal).padding(.vertical, 10)
                        }

                        Divider().background(AppColors.separator).padding(.leading, 52)

                        Menu {
                            ForEach(AppLanguage.allCases) { lang in
                                Button(lang.displayName) {
                                    UserDefaults.standard.set(lang.rawValue, forKey: "appLanguage")
                                }
                            }
                        } label: {
                            HStack(spacing: 12) {
                                iconBox("globe", bg: AppColors.green)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(L10n.language).foregroundColor(AppColors.textPrimary).font(AppTypography.body)
                                    Text(L10n.languageSubtitle).foregroundColor(AppColors.textTertiary).font(AppTypography.caption)
                                }
                                Spacer()
                                Text(AppLanguage.current.displayName).foregroundColor(AppColors.textSecondary).font(AppTypography.caption)
                                Image(systemName: "chevron.up.chevron.down").font(.caption2).foregroundColor(AppColors.textTertiary)
                            }
                            .padding(.horizontal).padding(.vertical, 10)
                        }
                    }

                    // Section: 清理设置
                    SettingsSectionHeader(title: L10n.cleanSettings)

                    settingsGroup {
                        // Threshold row
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

                        SettingsToggleRow(icon: "calendar", iconBg: AppColors.amber,
                                          title: L10n.timeWeight, subtitle: L10n.timeWeightDesc,
                                          isOn: $timeWeight)
                        Divider().background(AppColors.separator).padding(.leading, 52)

                        SettingsToggleRow(icon: "shield.fill", iconBg: AppColors.red,
                                          title: L10n.protectFace, subtitle: L10n.protectFaceDesc,
                                          isOn: $protectFaces)
                    }

                    // Threshold slider (expandable)
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

                    // Section: 通知与隐私
                    SettingsSectionHeader(title: L10n.notificationPrivacy)

                    settingsGroup {
                        SettingsToggleRow(icon: "bell.fill", iconBg: AppColors.blue,
                                          title: L10n.dailyReminder, subtitle: L10n.dailyReminderDesc,
                                          isOn: $dailyReminder)
                        Divider().background(AppColors.separator).padding(.leading, 52)

                        HStack(spacing: 12) {
                            iconBox("lock.fill", bg: AppColors.purple)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(L10n.localAI).foregroundColor(AppColors.textPrimary).font(AppTypography.body)
                                Text(L10n.localAIDesc).foregroundColor(AppColors.textTertiary).font(.caption)
                            }
                            Spacer()
                            Text(L10n.enabled).foregroundColor(AppColors.textTertiary).font(.caption)
                            Image(systemName: "chevron.right").font(.caption).foregroundColor(AppColors.textTertiary)
                        }
                        .padding(.horizontal).padding(.vertical, 10)
                    }

                    // Section: 数据统计
                    SettingsSectionHeader(title: L10n.statistics)

                    settingsGroup {
                        statRow(icon: "trash.fill", iconBg: AppColors.red,
                                title: L10n.totalFreed,
                                value: ByteCountFormatter.string(fromByteCount: stats.freedBytes, countStyle: .file))
                        Divider().background(AppColors.separator).padding(.leading, 52)
                        statRow(icon: "checkmark.circle.fill", iconBg: AppColors.green,
                                title: L10n.totalCleanups,
                                value: L10n.times(stats.scanCount))
                        Divider().background(AppColors.separator).padding(.leading, 52)
                        statRow(icon: "chart.bar.fill", iconBg: AppColors.amber,
                                title: L10n.healthImprovement,
                                value: stats.healthGain > 0 ? "+\(L10n.points(stats.healthGain))"
                                     : stats.scanCount > 0  ? L10n.improving
                                     :                        L10n.noData)
                    }
                    .task { stats = await DatabaseService.shared.loadCleaningStats() }

                    // Version
                    Text("PhotoCleaner v1.0.0")
                        .font(.caption).foregroundColor(AppColors.textTertiary)
                        .padding(.top, 24).padding(.bottom, 8)
                }
            }
        }
        .navigationBarHidden(true)
    }

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

    func statRow(icon: String, iconBg: Color, title: String, value: String) -> some View {
        HStack(spacing: 12) {
            iconBox(icon, bg: iconBg)
            Text(title).foregroundColor(AppColors.textPrimary).font(AppTypography.body)
            Spacer()
            Text(value).foregroundColor(AppColors.textSecondary).font(AppTypography.body)
        }
        .padding(.horizontal).padding(.vertical, 10)
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
