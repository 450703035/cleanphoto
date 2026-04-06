import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var vm: ScanViewModel
    @AppStorage("autoSelect")   private var autoSelect   = true
    @AppStorage("timeWeight")   private var timeWeight   = true
    @AppStorage("protectFaces") private var protectFaces = true
    @AppStorage("dailyReminder") private var dailyReminder = false
    @AppStorage("deleteThreshold") private var threshold = 40
    @State private var showThresholdPicker = false
    @State private var stats: DatabaseService.CleaningStats = .zero

    var body: some View {
        ZStack {
            AppColors.darkBG.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 0) {
                    // User header
                    HStack(spacing: 14) {
                        Circle()
                            .fill(Color(hex: "312e81"))
                            .frame(width: 52, height: 52)
                            .overlay(Image(systemName: "person.fill").font(.title3).foregroundColor(.white))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("用户账号").font(.system(size: 15, weight: .bold)).foregroundColor(.white)
                            Text("免费版").font(.caption).foregroundColor(AppColors.textSecondary)
                        }
                        Spacer()
                        Button("升级 Pro") {}
                            .font(.system(size: 11, weight: .bold))
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(AppColors.purple).foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .padding()

                    // Section: 清理设置
                    SettingsSectionHeader(title: "清理设置")

                    settingsGroup {
                        // Threshold row
                        Button {
                            showThresholdPicker.toggle()
                        } label: {
                            HStack(spacing: 12) {
                                iconBox("target", bg: AppColors.purple.opacity(0.2))
                                VStack(alignment: .leading, spacing: 1) {
                                    Text("删除阈值").foregroundColor(.white).font(.subheadline)
                                    Text("低于 \(threshold) 分自动推荐删除").foregroundColor(AppColors.textTertiary).font(.caption)
                                }
                                Spacer()
                                Text("\(threshold)").foregroundColor(AppColors.textTertiary).font(.subheadline)
                                Image(systemName: "chevron.right").font(.caption).foregroundColor(AppColors.textTertiary)
                            }
                            .padding(.horizontal).padding(.vertical, 10)
                        }

                        Divider().background(AppColors.separator).padding(.leading, 52)

                        SettingsToggleRow(icon: "arrow.triangle.2.circlepath", iconBg: AppColors.green.opacity(0.2),
                                          title: "自动勾选", subtitle: "扫描后自动选中推荐项",
                                          isOn: $autoSelect)
                        Divider().background(AppColors.separator).padding(.leading, 52)

                        SettingsToggleRow(icon: "calendar", iconBg: AppColors.amber.opacity(0.2),
                                          title: "时间权重", subtitle: "越早的照片评分越低",
                                          isOn: $timeWeight)
                        Divider().background(AppColors.separator).padding(.leading, 52)

                        SettingsToggleRow(icon: "shield.fill", iconBg: AppColors.red.opacity(0.2),
                                          title: "保护人脸照片", subtitle: "含人脸照片不自动删除",
                                          isOn: $protectFaces)
                    }

                    // Threshold slider (expandable)
                    if showThresholdPicker {
                        VStack(spacing: 8) {
                            HStack {
                                Text("当前阈值：\(threshold) 分").font(.subheadline).foregroundColor(.white)
                                Spacer()
                            }
                            Slider(value: Binding(get: { Double(threshold) }, set: { threshold = Int($0) }),
                                   in: 10...80, step: 1)
                                .tint(AppColors.purple)
                            HStack {
                                Text("宽松 (10)").font(.caption).foregroundColor(AppColors.textSecondary)
                                Spacer()
                                Text("严格 (80)").font(.caption).foregroundColor(AppColors.textSecondary)
                            }
                        }
                        .padding()
                        .background(AppColors.cardBG)
                        .cornerRadius(14)
                        .padding(.horizontal)
                        .padding(.top, 4)
                    }

                    // Section: 通知与隐私
                    SettingsSectionHeader(title: "通知与隐私")

                    settingsGroup {
                        SettingsToggleRow(icon: "bell.fill", iconBg: AppColors.blue.opacity(0.2),
                                          title: "每日清理提醒", subtitle: "每天提醒完成清理任务",
                                          isOn: $dailyReminder)
                        Divider().background(AppColors.separator).padding(.leading, 52)

                        HStack(spacing: 12) {
                            iconBox("lock.fill", bg: AppColors.purple.opacity(0.2))
                            VStack(alignment: .leading, spacing: 1) {
                                Text("本地 AI 分析").foregroundColor(.white).font(.subheadline)
                                Text("所有分析均在设备上完成").foregroundColor(AppColors.textTertiary).font(.caption)
                            }
                            Spacer()
                            Text("已开启").foregroundColor(AppColors.textTertiary).font(.caption)
                            Image(systemName: "chevron.right").font(.caption).foregroundColor(AppColors.textTertiary)
                        }
                        .padding(.horizontal).padding(.vertical, 10)
                    }

                    // Section: 数据统计
                    SettingsSectionHeader(title: "数据统计")

                    settingsGroup {
                        statRow(icon: "trash.fill", iconBg: AppColors.red.opacity(0.2),
                                title: "累计释放空间",
                                value: ByteCountFormatter.string(fromByteCount: stats.freedBytes, countStyle: .file))
                        Divider().background(AppColors.separator).padding(.leading, 52)
                        statRow(icon: "checkmark.circle.fill", iconBg: AppColors.green.opacity(0.2),
                                title: "累计清理次数",
                                value: "\(stats.scanCount) 次")
                        Divider().background(AppColors.separator).padding(.leading, 52)
                        statRow(icon: "chart.bar.fill", iconBg: AppColors.amber.opacity(0.2),
                                title: "相册健康提升",
                                value: stats.healthGain > 0 ? "+\(stats.healthGain) 分"
                                     : stats.scanCount > 0  ? "持续优化中"
                                     :                        "暂无数据")
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
        .background(Color.white.opacity(0.04))
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.07), lineWidth: 0.5))
        .padding(.horizontal)
        .padding(.bottom, 4)
    }

    func iconBox(_ name: String, bg: Color) -> some View {
        Image(systemName: name).font(.system(size: 14))
            .frame(width: 30, height: 30).background(bg).foregroundColor(.white).cornerRadius(8)
    }

    func statRow(icon: String, iconBg: Color, title: String, value: String) -> some View {
        HStack(spacing: 12) {
            iconBox(icon, bg: iconBg)
            Text(title).foregroundColor(.white).font(.subheadline)
            Spacer()
            Text(value).foregroundColor(AppColors.textSecondary).font(.subheadline)
        }
        .padding(.horizontal).padding(.vertical, 10)
    }
}

struct SettingsSectionHeader: View {
    let title: String
    var body: some View {
        Text(title)
            .font(.caption).fontWeight(.semibold)
            .foregroundColor(AppColors.textTertiary)
            .textCase(.uppercase)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
            .padding(.top, 20).padding(.bottom, 7)
    }
}
