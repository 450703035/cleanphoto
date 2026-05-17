import SwiftUI
import Photos
import UIKit

private enum AnnualReportPageKind: Int, CaseIterable {
    case cover
    case total
    case time
    case content
    case person
    case waste
    case reveal
    case ending
}

struct AnnualReportView: View {
    let data: InsightsData
    let initialPersona: Persona

    @Environment(\.dismiss) private var dismiss
    @State private var pageIndex: Int = 0

    init(data: InsightsData, initialPersona: Persona) {
        self.data = data
        self.initialPersona = initialPersona
    }

    private var pageKinds: [AnnualReportPageKind] { AnnualReportPageKind.allCases }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                TabView(selection: $pageIndex) {
                    ForEach(Array(pageKinds.enumerated()), id: \.offset) { pair in
                        AnnualReportPageView(
                            kind: pair.element,
                            data: data,
                            persona: initialPersona,
                            active: pageIndex == pair.offset
                        )
                        .tag(pair.offset)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .ignoresSafeArea()

                VStack {
                    Spacer().frame(height: geo.safeAreaInsets.top + 14)
                    HStack(spacing: 4) {
                        ForEach(pageKinds.indices, id: \.self) { idx in
                            Capsule()
                                .fill(idx == pageIndex ? Color.white : Color.white.opacity(0.35))
                                .frame(width: idx == pageIndex ? 16 : 5, height: 5)
                                .animation(.easeOut(duration: 0.28), value: pageIndex)
                        }
                    }
                    Spacer()
                }
                .allowsHitTesting(false)

                VStack {
                    HStack {
                        Spacer()
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 32, height: 32)
                                .background(Color.white.opacity(0.16))
                                .overlay(
                                    Circle().stroke(Color.white.opacity(0.25), lineWidth: 0.5)
                                )
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, geo.safeAreaInsets.top + 8)
                    .padding(.horizontal, 18)
                    Spacer()
                }
            }
            .onAppear {
                pageIndex = 0
            }
        }
        .interactiveDismissDisabled()
    }
}

private struct AnnualReportPageView: View {
    let kind: AnnualReportPageKind
    let data: InsightsData
    let persona: Persona
    let active: Bool
    @State private var entered = false
    @State private var shareItem: AnnualShareItem?
    @State private var saveAlert: AnnualSaveAlert?

    private var monthPeak: (index: Int, count: Int) {
        let maxEntry = data.monthBars.enumerated().max { $0.element < $1.element }
        return (maxEntry?.offset ?? 0, maxEntry?.element ?? 0)
    }

    private var screenshotRevisitPct: Int { max(0, 100 - data.screenshotUnusedPct) }
    private var screenshotYearSharePct: Int {
        guard data.yearTotal > 0 else { return 0 }
        return Int(round(Double(data.screenshotTotal) / Double(data.yearTotal) * 100))
    }

    private var peakHourLabel: String {
        String(format: "%02d:00", max(0, min(23, data.peakHour)))
    }

    private var endingLine2: String {
        persona.endingLine2Html
            .replacingOccurrences(of: "<br/>", with: "\n")
            .replacingOccurrences(of: "<br>", with: "\n")
    }

    var body: some View {
        ZStack {
            background(for: kind).ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                Spacer().frame(height: 88)
                content
                Spacer(minLength: 56)
            }
            .padding(.horizontal, 28)
            .foregroundColor(.white)
        }
        .onAppear {
            if active { triggerEnter() }
        }
        .onChange(of: active) { isActive in
            if isActive { triggerEnter() } else { entered = false }
        }
        .onChange(of: persona.id) { _ in
            if active { triggerEnter() }
        }
        .sheet(item: $shareItem) { item in
            AnnualActivityView(activityItems: [item.image])
        }
        .alert(item: $saveAlert) { alert in
            Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                dismissButton: .default(Text(L10n.isEn ? "OK" : "好"))
            )
        }
    }

    private func triggerEnter() {
        entered = false
        DispatchQueue.main.async {
            entered = true
        }
    }

    @ViewBuilder
    private var content: some View {
        switch kind {
        case .cover:
            VStack(alignment: .leading, spacing: 0) {
                Spacer()
                Text(L10n.annualEyebrow)
                    .font(.system(size: 13, weight: .semibold))
                    .tracking(2.5)
                    .textCase(.uppercase)
                    .opacity(0.82)
                    .padding(.bottom, 12)
                    .annualFadeUp(entered: entered, delay: 0.05)
                Text("\(data.year)\n\(L10n.annualCoverTitle)")
                    .font(.system(size: 72, weight: .black))
                    .tracking(-3)
                    .lineSpacing(-2)
                    .padding(.bottom, 20)
                    .annualFadeUp(entered: entered, delay: 0.15)
                Text(L10n.annualCoverBody(data.yearTotal))
                    .font(.system(size: 17))
                    .lineSpacing(3)
                    .opacity(0.88)
                    .annualFadeUp(entered: entered, delay: 0.28)
                Spacer()
                Text(L10n.annualSwipeRight)
                    .font(.system(size: 13))
                    .opacity(0.55)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .annualFadeUp(entered: entered, delay: 0.45)
            }

        case .total:
            VStack(alignment: .leading, spacing: 0) {
                Spacer()
                Text(L10n.annualTotalLeading)
                    .font(.system(size: 15))
                    .opacity(0.75)
                    .padding(.bottom, 12)
                    .annualFadeUp(entered: entered, delay: 0.05)
                Text(data.yearTotal.formatted())
                    .font(.system(size: 92, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .tracking(-4)
                    .lineLimit(1)
                    .annualFadeUp(entered: entered, delay: 0.15)
                Text(L10n.annualTotalTrailing(data.yearSizeGB))
                    .font(.system(size: 17))
                    .opacity(0.75)
                    .padding(.top, 10)
                    .padding(.bottom, 30)
                    .annualFadeUp(entered: entered, delay: 0.28)

                AnnualMonthBars(values: data.monthBars, peakIndex: monthPeak.index, active: entered)
                    .frame(height: 160)
                    .annualFadeUp(entered: entered, delay: 0.4)
                Text(L10n.annualTopMonth(L10n.monthLabel(monthPeak.index + 1), monthPeak.count))
                    .font(.system(size: 14))
                    .opacity(0.85)
                    .padding(.top, 16)
                    .annualFadeUp(entered: entered, delay: 0.7)
                Spacer()
            }

        case .time:
            VStack(alignment: .leading, spacing: 0) {
                Spacer()
                Text(L10n.annualTimeLeading)
                    .font(.system(size: 15))
                    .opacity(0.75)
                    .padding(.bottom, 14)
                    .annualFadeUp(entered: entered, delay: 0.05)
                Text(peakHourLabel)
                    .font(.system(size: 108, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .tracking(-4)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .allowsTightening(true)
                    .annualFadeUp(entered: entered, delay: 0.15)
                Text(L10n.annualTimeBody)
                    .font(.system(size: 17))
                    .opacity(0.78)
                    .padding(.top, 10)
                    .padding(.bottom, 28)
                    .annualFadeUp(entered: entered, delay: 0.28)
                AnnualHourBars(values: data.hourHistogram, peakHour: data.peakHour, active: entered)
                    .frame(height: 140)
                    .annualFadeUp(entered: entered, delay: 0.4)
                Spacer()
            }

        case .content:
            VStack(alignment: .leading, spacing: 0) {
                Spacer()
                Text(L10n.annualContentLeading)
                    .font(.system(size: 15))
                    .opacity(0.75)
                    .padding(.bottom, 14)
                    .annualFadeUp(entered: entered, delay: 0.05)
                Text("\(data.mixTopLabel)\n\(L10n.isEn ? "and Screenshots" : "和截图")")
                    .font(.system(size: 50, weight: .black))
                    .tracking(-1.5)
                    .lineSpacing(2)
                    .padding(.bottom, 20)
                    .annualFadeUp(entered: entered, delay: 0.15)

                VStack(spacing: 12) {
                    let slices = Array(data.contentMix.prefix(5))
                    let maxValue = max(1.0, slices.map { $0.value }.max() ?? 1)
                    ForEach(Array(slices.enumerated()), id: \.element.id) { pair in
                        let idx = pair.offset
                        let slice = pair.element
                        VStack(spacing: 5) {
                            HStack {
                                Text(slice.label)
                                    .font(.system(size: 14, weight: .medium))
                                Spacer()
                                Text("\(Int(round(slice.value)))%")
                                    .font(.system(size: 14, design: .rounded))
                                    .monospacedDigit()
                                    .opacity(0.75)
                            }
                            GeometryReader { geo in
                                Capsule()
                                    .fill(Color.white.opacity(0.12))
                                    .overlay(alignment: .leading) {
                                        Capsule()
                                            .fill(slice.color)
                                            .frame(width: geo.size.width * CGFloat(slice.value / maxValue) * (entered ? 1 : 0))
                                            .animation(.easeOut(duration: 0.9).delay(0.45 + Double(idx) * 0.1), value: entered)
                                    }
                            }
                            .frame(height: 8)
                        }
                        .annualFadeUp(entered: entered, delay: 0.28 + Double(idx) * 0.08)
                    }
                }
                Spacer()
            }

        case .person:
            VStack(alignment: .leading, spacing: 0) {
                Spacer()
                Text(L10n.annualPersonLeading)
                    .font(.system(size: 15))
                    .opacity(0.8)
                    .padding(.bottom, 12)
                    .annualFadeUp(entered: entered, delay: 0.05)
                Text("👶")
                    .font(.system(size: 84))
                    .frame(width: 180, height: 180)
                    .background(Color.white.opacity(0.12))
                    .clipShape(Circle())
                    .padding(.bottom, 18)
                    .annualFadeUp(entered: entered, delay: 0.18)
                Text(L10n.annualPersonLabel)
                    .font(.system(size: 54, weight: .black))
                    .tracking(-2)
                    .padding(.bottom, 8)
                    .annualFadeUp(entered: entered, delay: 0.32)
                Text(L10n.annualPersonBody(2830, 59))
                    .font(.system(size: 16))
                    .opacity(0.88)
                    .padding(.bottom, 22)
                    .annualFadeUp(entered: entered, delay: 0.42)
                Text(L10n.annualPersonLine)
                    .font(.system(size: 14))
                    .lineSpacing(3)
                    .opacity(0.78)
                    .annualFadeUp(entered: entered, delay: 0.56)
                Spacer()
            }

        case .waste:
            VStack(alignment: .leading, spacing: 0) {
                Spacer()
                Text(L10n.annualWasteLeading)
                    .font(.system(size: 15))
                    .opacity(0.75)
                    .padding(.bottom, 16)
                    .annualFadeUp(entered: entered, delay: 0.05)
                Text(data.screenshotTotal.formatted())
                    .font(.system(size: 84, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .tracking(-3)
                    .annualFadeUp(entered: entered, delay: 0.15)
                Text(L10n.annualWasteBody(data.screenshotTotal, screenshotYearSharePct))
                    .font(.system(size: 17))
                    .opacity(0.75)
                    .padding(.top, 8)
                    .padding(.bottom, 28)
                    .annualFadeUp(entered: entered, delay: 0.26)

                VStack(alignment: .leading, spacing: 12) {
                    Text(L10n.annualWasteRevisited)
                        .font(.system(size: 13))
                        .opacity(0.75)
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("\(screenshotRevisitPct)")
                            .font(.system(size: 44, weight: .black, design: .rounded))
                            .monospacedDigit()
                            .foregroundColor(Color(hex: "f5c04e"))
                        Text("% \(L10n.annualWasteMostForgotten)")
                            .font(.system(size: 13))
                            .opacity(0.66)
                    }
                    Capsule()
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 8)
                        .overlay(alignment: .leading) {
                            Capsule()
                                .fill(Color(hex: "f5c04e"))
                                .frame(width: CGFloat(screenshotRevisitPct) * 2.2 * (entered ? 1 : 0))
                                .animation(.easeOut(duration: 1.1).delay(0.6), value: entered)
                        }
                    Text(L10n.annualWasteCta)
                        .font(.system(size: 13))
                        .opacity(0.86)
                }
                .padding(18)
                .background(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                )
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .annualFadeUp(entered: entered, delay: 0.38)
                Spacer()
            }

        case .reveal:
            VStack(spacing: 0) {
                Spacer()
                Text(L10n.annualPersonaEyebrow(data.year))
                    .font(.system(size: 13, weight: .semibold))
                    .tracking(2.3)
                    .textCase(.uppercase)
                    .opacity(0.75)
                    .padding(.bottom, 20)
                    .annualFadeUp(entered: entered, delay: 0.05)
                Text(persona.symbol)
                    .font(.system(size: 74))
                    .frame(width: 160, height: 160)
                    .background(Color.white.opacity(0.1))
                    .overlay(
                        Circle().stroke(Color.white.opacity(0.22), lineWidth: 0.5)
                    )
                    .clipShape(Circle())
                    .padding(.bottom, 24)
                    .annualFadeUp(entered: entered, delay: 0.18)
                Text(persona.eyebrow)
                    .font(.system(size: 52, weight: .black))
                    .tracking(-2)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 14)
                    .annualFadeUp(entered: entered, delay: 0.32)
                Text(persona.endingLine1)
                    .font(.system(size: 15))
                    .opacity(0.84)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 24)
                    .annualFadeUp(entered: entered, delay: 0.45)
                VStack(spacing: 6) {
                    Text(persona.endingStat.value)
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .monospacedDigit()
                    Text(persona.endingStat.label)
                        .font(.system(size: 11))
                        .opacity(0.68)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 16)
                .background(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.15), lineWidth: 0.5)
                )
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .annualFadeUp(entered: entered, delay: 0.58)
                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .center)

        case .ending:
            VStack(spacing: 0) {
                Spacer()
                Text("\(data.year) · \(persona.eyebrow)")
                    .font(.system(size: 13))
                    .opacity(0.72)
                    .padding(.bottom, 18)
                    .annualFadeUp(entered: entered, delay: 0.05)
                Text(endingLine2)
                    .font(.system(size: 40, weight: .black))
                    .tracking(-1.2)
                    .lineSpacing(4)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 22)
                    .annualFadeUp(entered: entered, delay: 0.15)
                Text(L10n.annualEndingWish.replacingOccurrences(of: "<br/>", with: "\n"))
                    .font(.system(size: 14))
                    .opacity(0.68)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.bottom, 34)
                    .annualFadeUp(entered: entered, delay: 0.32)
                HStack(spacing: 10) {
                    Button {
                        saveAnnualEndingImage()
                    } label: {
                        Text(L10n.annualBtnSaveImage)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color.black.opacity(0.92))
                            .padding(.horizontal, 20)
                            .padding(.vertical, 11)
                            .background(Color.white)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)

                    Button {
                        shareAnnualEndingImage()
                    } label: {
                        Text(L10n.annualBtnShare)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 11)
                            .background(Color.white.opacity(0.12))
                            .overlay(Capsule().stroke(Color.white.opacity(0.2), lineWidth: 0.5))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .annualFadeUp(entered: entered, delay: 0.45)
                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    private func shareAnnualEndingImage() {
        guard let image = renderAnnualEndingImage() else { return }
        shareItem = AnnualShareItem(image: image)
    }

    private func saveAnnualEndingImage() {
        guard let image = renderAnnualEndingImage() else { return }
        Task {
            do {
                try await AnnualImageSaver.save(image)
                await MainActor.run {
                    saveAlert = AnnualSaveAlert(
                        title: L10n.isEn ? "Saved" : "已保存",
                        message: L10n.isEn ? "The annual report image was saved to Photos." : "年报图片已保存到相册。"
                    )
                }
            } catch {
                await MainActor.run {
                    saveAlert = AnnualSaveAlert(
                        title: L10n.isEn ? "Couldn't save" : "保存失败",
                        message: L10n.isEn ? "Please allow photo access and try again." : "请允许相册权限后再试一次。"
                    )
                }
            }
        }
    }

    @MainActor
    private func renderAnnualEndingImage() -> UIImage? {
        let renderer = ImageRenderer(
            content: AnnualEndingShareCard(
                year: data.year,
                persona: persona,
                endingLine2: endingLine2
            )
            .frame(width: 1080, height: 1920)
        )
        renderer.scale = 1
        return renderer.uiImage
    }

    private func background(for kind: AnnualReportPageKind) -> LinearGradient {
        switch kind {
        case .cover:
            return LinearGradient(colors: [Color(hex: "8d472e"), Color(hex: "321a52")], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .total:
            return LinearGradient(colors: [Color(hex: "48342a"), Color(hex: "251d1b")], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .time:
            return LinearGradient(colors: [Color(hex: "2f3457"), Color(hex: "171a2b")], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .content:
            return LinearGradient(colors: [Color(hex: "5a2d54"), Color(hex: "2a1730")], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .person:
            return LinearGradient(colors: [Color(hex: "b17744"), Color(hex: "5a341f")], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .waste:
            return LinearGradient(colors: [Color(hex: "2a3c67"), Color(hex: "171e35")], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .reveal, .ending:
            return LinearGradient(colors: persona.gradient, startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
}

private struct AnnualShareItem: Identifiable {
    let id = UUID()
    let image: UIImage
}

private struct AnnualSaveAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

private struct AnnualEndingShareCard: View {
    let year: Int
    let persona: Persona
    let endingLine2: String

    var body: some View {
        ZStack {
            LinearGradient(colors: persona.gradient, startPoint: .topLeading, endPoint: .bottomTrailing)

            PersonaMotif(id: persona.id)
                .opacity(0.28)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [persona.glow, .clear],
                        center: .center,
                        startRadius: 24,
                        endRadius: 420
                    )
                )
                .frame(width: 680, height: 680)
                .offset(x: 260, y: -430)
                .blur(radius: 18)

            VStack(spacing: 0) {
                Spacer()

                Text("\(year) · \(persona.eyebrow)")
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundColor(.white.opacity(0.72))
                    .padding(.bottom, 56)

                Text(endingLine2)
                    .font(.system(size: 112, weight: .black))
                    .tracking(-2)
                    .lineSpacing(12)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white)
                    .padding(.horizontal, 86)
                    .padding(.bottom, 58)

                Text(L10n.annualEndingWish.replacingOccurrences(of: "<br/>", with: "\n"))
                    .font(.system(size: 42, weight: .regular))
                    .lineSpacing(10)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white.opacity(0.68))

                Spacer()

                Text(L10n.isEn ? "Lighten" : "轻相册")
                    .font(.system(size: 34, weight: .semibold))
                    .tracking(1.2)
                    .foregroundColor(.white.opacity(0.45))
                    .padding(.bottom, 90)
            }
        }
        .ignoresSafeArea()
    }
}

private struct AnnualActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

private enum AnnualImageSaver {
    static func save(_ image: UIImage) async throws {
        let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        if status == .notDetermined {
            let updated = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
            guard updated == .authorized || updated == .limited else {
                throw AnnualImageSaveError.denied
            }
        } else if status != .authorized && status != .limited {
            throw AnnualImageSaveError.denied
        }

        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.creationRequestForAsset(from: image)
        }
    }
}

private enum AnnualImageSaveError: Error {
    case denied
}

private struct AnnualMonthBars: View {
    let values: [Int]
    let peakIndex: Int
    let active: Bool

    var body: some View {
        let bars = values.isEmpty ? [Int](repeating: 0, count: 12) : values
        let maxValue = max(1, bars.max() ?? 1)
        HStack(alignment: .bottom, spacing: 4) {
            ForEach(Array(bars.enumerated()), id: \.offset) { item in
                let height = max(4.0, CGFloat(item.element) / CGFloat(maxValue) * 120)
                RoundedRectangle(cornerRadius: 3)
                    .fill(item.offset == peakIndex ? Color.white : Color.white.opacity(0.72))
                    .frame(maxWidth: .infinity)
                    .frame(height: active ? height : 4)
                    .animation(.easeOut(duration: 0.9).delay(0.4 + Double(item.offset) * 0.035), value: active)
            }
        }
        .frame(maxWidth: .infinity, alignment: .bottom)
    }
}

private struct AnnualHourBars: View {
    let values: [Double]
    let peakHour: Int
    let active: Bool

    var body: some View {
        let bars = values.count == 24 ? values : Array(repeating: 0.2, count: 24)
        HStack(alignment: .bottom, spacing: 3) {
            ForEach(Array(bars.enumerated()), id: \.offset) { item in
                RoundedRectangle(cornerRadius: 2.5)
                    .fill(item.offset == peakHour ? Color(hex: "f0b34d") : Color.white.opacity(0.55))
                    .frame(maxWidth: .infinity)
                    .frame(height: active ? max(3.0, CGFloat(item.element) * 120) : 3)
                    .animation(.easeOut(duration: 0.7).delay(0.5 + Double(item.offset) * 0.022), value: active)
            }
        }
        .frame(maxWidth: .infinity, alignment: .bottom)
    }
}

private struct AnnualFadeUpModifier: ViewModifier {
    let entered: Bool
    let delay: Double
    let distance: CGFloat

    func body(content: Content) -> some View {
        content
            .opacity(entered ? 1 : 0)
            .offset(y: entered ? 0 : distance)
            .animation(.easeOut(duration: 0.7).delay(delay), value: entered)
    }
}

private extension View {
    func annualFadeUp(entered: Bool, delay: Double = 0, distance: CGFloat = 14) -> some View {
        modifier(AnnualFadeUpModifier(entered: entered, delay: delay, distance: distance))
    }
}
