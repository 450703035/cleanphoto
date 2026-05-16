import SwiftUI

// MARK: - Theme tokens local to insights screen
enum InsightsTheme {
    static let accent     = Color(hex: "ff9b4b")
    static let accentInk  = Color(hex: "7a3b12")
    static let accentSoft = Color(hex: "fff4e9")
    static let ink        = Color(lightHex: "0a0a0b", darkHex: "f5f5f7")
    static let ink2       = Color(lightHex: "3c3c43", darkHex: "f5f5f7", lightAlpha: 0.78, darkAlpha: 0.78)
    static let ink3       = Color(lightHex: "3c3c43", darkHex: "f5f5f7", lightAlpha: 0.6,  darkAlpha: 0.55)
    static let ink4       = Color(lightHex: "3c3c43", darkHex: "f5f5f7", lightAlpha: 0.3,  darkAlpha: 0.28)
    static let card       = Color(lightHex: "ffffff", darkHex: "1d1d1f")
    static let bg         = Color(lightHex: "f2f2f7", darkHex: "0b0b0c")
    static let chipBg     = Color(lightHex: "000000", darkHex: "ffffff", lightAlpha: 0.06, darkAlpha: 0.1)
    static let separator  = Color(lightHex: "000000", darkHex: "ffffff", lightAlpha: 0.08, darkAlpha: 0.12)
    static let greenOK    = Color(hex: "2aaa55")
    static let screenshotCardBg = Color(lightHex: "f5f9ff", darkHex: "1f222b")
    static let ctaTextOnInk = Color(lightHex: "ffffff", darkHex: "0a0a0b")
}

// MARK: - Card shell

struct InsightsCard<Content: View>: View {
    var padding: CGFloat = 18
    var background: Color? = nil
    @ViewBuilder var content: () -> Content
    @State private var pressed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
        }
        .padding(padding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(background ?? InsightsTheme.card)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
    }
}

// MARK: - Section header

struct InsightsSectionHeader: View {
    let eyebrow: String
    let title: String
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(eyebrow)
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.6)
                .foregroundColor(InsightsTheme.ink3)
                .textCase(.uppercase)
            Text(title)
                .font(.system(size: 22, weight: .semibold))
                .tracking(-0.5)
                .foregroundColor(InsightsTheme.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 10)
    }
}

// MARK: - 7-day bars

struct Week7Bars: View {
    let data: [Int]
    var highlightIndex: Int = 5
    var accent: Color = InsightsTheme.accent
    @State private var animate = false

    private var labels: [String] {
        L10n.isEn ? ["M","T","W","T","F","S","S"] : ["一","二","三","四","五","六","日"]
    }

    var body: some View {
        let maxV = max(1, data.max() ?? 1)
        HStack(alignment: .bottom, spacing: 8) {
            ForEach(0..<data.count, id: \.self) { i in
                let value = data[i]
                let frac = Double(value) / Double(maxV)
                let h = max(4, frac * 80)
                let isToday = i == highlightIndex

                VStack(spacing: 6) {
                    ZStack(alignment: .top) {
                        RoundedRectangle(cornerRadius: 5)
                            .fill(isToday ? accent : InsightsTheme.chipBg)
                            .frame(height: animate ? h : 0)

                        if isToday && animate {
                            Text("\(value)")
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .monospacedDigit()
                                .foregroundColor(accent)
                                .offset(y: -18)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 88, alignment: .bottom)

                    Text(labels[i])
                        .font(.system(size: 11, weight: isToday ? .semibold : .regular))
                        .foregroundColor(InsightsTheme.ink3)
                }
            }
        }
        .frame(height: 108)
        .onAppear {
            restartAnimation()
        }
        .onChange(of: data) { _ in
            restartAnimation()
        }
    }

    private func restartAnimation() {
        animate = false
        DispatchQueue.main.async {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.9)) { animate = true }
        }
    }
}

// MARK: - 24-hour histogram

struct HourHistogram: View {
    let data: [Double]     // 24 values 0..1
    var accent: Color = Color(hex: "ff9b4b")
    @State private var animate = false

    var body: some View {
        GeometryReader { geo in
            let barW = max(3.0, (geo.size.width - 16) / 40.0)
            let peak: Int = data.enumerated().max(by: { $0.element < $1.element })?.offset ?? 22
            ZStack(alignment: .bottom) {
                HStack(alignment: .bottom, spacing: 3) {
                    ForEach(0..<24, id: \.self) { h in
                        let value = data[h]
                        let heightFrac = animate ? value : 0
                        RoundedRectangle(cornerRadius: 2)
                            .fill(h == peak ? accent : InsightsTheme.chipBg)
                            .frame(width: barW, height: max(3, CGFloat(heightFrac) * geo.size.height))
                    }
                }
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .bottom)
        }
        .frame(height: 84)
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) { animate = true }
        }
    }
}

// MARK: - Donut

struct ContentMixDonut: View {
    let slices: [ContentMixSlice]
    let centerLabel: String
    let centerSub: String
    var size: CGFloat = 116
    var thickness: CGFloat = 14

    @State private var animationFrac: Double = 0

    private var total: Double { slices.reduce(0) { $0 + $1.value } }

    var body: some View {
        ZStack {
            Circle()
                .stroke(InsightsTheme.chipBg, lineWidth: thickness)
            donutSlices
            VStack(spacing: 2) {
                Text(centerLabel)
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(InsightsTheme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
                    .frame(maxWidth: size - thickness * 2 - 8)
                Text(centerSub)
                    .font(.system(size: 11))
                    .foregroundColor(InsightsTheme.ink3)
            }
        }
        .frame(width: size, height: size)
        .onAppear {
            withAnimation(.easeOut(duration: 0.9)) { animationFrac = 1 }
        }
    }

    private var donutSlices: some View {
        let sum = max(0.01, total)
        var cumulative = 0.0
        return ZStack {
            ForEach(slices) { slice in
                let start = cumulative / sum
                let end = (cumulative + slice.value) / sum
                let trimEnd = start + (end - start) * animationFrac
                let _ = (cumulative += slice.value)
                Circle()
                    .trim(from: start, to: trimEnd)
                    .stroke(slice.color, style: StrokeStyle(lineWidth: thickness, lineCap: .butt))
                    .rotationEffect(.degrees(-90))
            }
        }
    }
}

struct DonutLegend: View {
    let slices: [ContentMixSlice]
    var body: some View {
        let total = max(0.01, slices.reduce(0) { $0 + $1.value })
        VStack(alignment: .leading, spacing: 7) {
            ForEach(slices.prefix(5)) { slice in
                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(slice.color)
                        .frame(width: 8, height: 8)
                    Text(slice.label)
                        .font(.system(size: 13))
                        .foregroundColor(InsightsTheme.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("\(Int(round(slice.value / total * 100)))%")
                        .font(.system(size: 12, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(InsightsTheme.ink3)
                }
            }
        }
    }
}

// MARK: - Persona Hero (single persona)

struct PersonaHero: View {
    struct Payload {
        let persona: Persona
        let year: Int
        let yearTotal: Int
    }

    let persona: Persona
    let year: Int
    let yearTotal: Int
    let previous: Payload?
    let next: Payload?
    let canSwipePrev: Bool
    let canSwipeNext: Bool
    var onSwipePrev: () -> Void
    var onSwipeNext: () -> Void
    var onReport: () -> Void
    @State private var dragOffset: CGFloat = 0
    @State private var committingSwipe = false

    private let slideDuration: Double = 0.42
    private var slideAnimation: Animation {
        .timingCurve(0.2, 0.8, 0.2, 1, duration: slideDuration)
    }

    private func adjustedDrag(_ raw: CGFloat) -> CGFloat {
        if (raw > 0 && !canSwipePrev) || (raw < 0 && !canSwipeNext) {
            return raw * 0.35
        }
        return raw
    }

    private func finishDrag(width: CGFloat) {
        guard !committingSwipe else { return }
        let threshold = width * 0.2
        if dragOffset <= -threshold, canSwipeNext {
            committingSwipe = true
            withAnimation(slideAnimation) { dragOffset = -width }
            DispatchQueue.main.asyncAfter(deadline: .now() + slideDuration) {
                onSwipeNext()
                dragOffset = 0
                committingSwipe = false
            }
            return
        }
        if dragOffset >= threshold, canSwipePrev {
            committingSwipe = true
            withAnimation(slideAnimation) { dragOffset = width }
            DispatchQueue.main.asyncAfter(deadline: .now() + slideDuration) {
                onSwipePrev()
                dragOffset = 0
                committingSwipe = false
            }
            return
        }

        withAnimation(slideAnimation) { dragOffset = 0 }
    }

    var body: some View {
        GeometryReader { geo in
            let width = max(1, geo.size.width)
            HStack(spacing: 0) {
                personaSlot(payload: previous)
                    .frame(width: width)
                PersonaPage(persona: persona, year: year, yearTotal: yearTotal, onReport: onReport)
                    .frame(width: width)
                personaSlot(payload: next)
                    .frame(width: width)
            }
            .offset(x: -width + dragOffset)
            .animation(.none, value: persona.id)
            .contentShape(Rectangle())
            .simultaneousGesture(
                DragGesture(minimumDistance: 8)
                    .onChanged { value in
                        guard !committingSwipe else { return }
                        let mostlyHorizontal = abs(value.translation.width) > abs(value.translation.height) * 1.2
                        guard mostlyHorizontal else { return }
                        dragOffset = adjustedDrag(value.translation.width)
                    }
                    .onEnded { value in
                        let mostlyHorizontal = abs(value.translation.width) > abs(value.translation.height) * 1.2
                        guard mostlyHorizontal else {
                            withAnimation(slideAnimation) { dragOffset = 0 }
                            return
                        }
                        finishDrag(width: width)
                    }
            )
        }
        .frame(height: 440)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.25), radius: 20, x: 0, y: 14)
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private func personaSlot(payload: Payload?) -> some View {
        if let payload {
            PersonaPage(
                persona: payload.persona,
                year: payload.year,
                yearTotal: payload.yearTotal,
                onReport: onReport
            )
        } else {
            Color.clear
        }
    }
}

private struct PersonaPage: View {
    let persona: Persona
    let year: Int
    let yearTotal: Int
    var onReport: () -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Gradient background
            LinearGradient(
                colors: persona.gradient,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Motif
            PersonaMotif(id: persona.id)
                .allowsHitTesting(false)

            // Glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [persona.glow, .clear],
                        center: .center,
                        startRadius: 8, endRadius: 160
                    )
                )
                .frame(width: 260, height: 260)
                .offset(x: 140, y: -80)
                .blur(radius: 8)
                .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: 0) {
                // Eyebrow
                HStack {
                    HStack(spacing: 7) {
                        Text(persona.symbol).font(.system(size: 14))
                        Text(L10n.insightsPersonaEyebrow + " · " + persona.eyebrow)
                            .font(.system(size: 11, weight: .semibold))
                            .tracking(1)
                            .textCase(.uppercase)
                            .foregroundColor(.white.opacity(0.75))
                    }
                    Spacer()
                }
                .padding(.bottom, 14)

                // Title
                Text(persona.title)
                    .font(.system(size: 32, weight: .heavy))
                    .tracking(-1.1)
                    .foregroundColor(.white)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                    .padding(.bottom, 8)

                Text(persona.line)
                    .font(.system(size: 14.5))
                    .foregroundColor(.white.opacity(0.82))
                    .lineSpacing(2)
                    .padding(.bottom, 16)

                // Tags
                HStack(spacing: 6) {
                    ForEach(persona.tags.prefix(4), id: \.self) { tag in
                        Text(tag)
                            .font(.system(size: 11.5))
                            .foregroundColor(.white.opacity(0.92))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.white.opacity(0.12))
                            .overlay(
                                Capsule().strokeBorder(Color.white.opacity(0.18), lineWidth: 0.5)
                            )
                            .clipShape(Capsule())
                    }
                }

                Spacer()

                // Stats row
                HStack(alignment: .top, spacing: 0) {
                    ForEach(persona.stats.indices, id: \.self) { i in
                        let s = persona.stats[i]
                        VStack(alignment: .leading, spacing: 3) {
                            Text(s.value)
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .monospacedDigit()
                                .tracking(-0.6)
                                .foregroundColor(.white)
                            Text(s.label)
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.58))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .overlay(alignment: .leading) {
                            if i > 0 {
                                Rectangle()
                                    .fill(Color.white.opacity(0.1))
                                    .frame(width: 0.5)
                            }
                        }
                        .padding(.leading, i == 0 ? 0 : 12)
                    }
                }
                .padding(.top, 14)
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(Color.white.opacity(0.15))
                        .frame(height: 0.5)
                }

                // CTA
                Button(action: onReport) {
                    HStack {
                        HStack(spacing: 10) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(hex: "ff9b4b"))
                                    .frame(width: 28, height: 28)
                                Image(systemName: "photo.stack")
                                    .font(.system(size: 14))
                                    .foregroundColor(.black)
                            }
                            VStack(alignment: .leading, spacing: 1) {
                                Text(L10n.viewAnnualReport(year))
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.white)
                                Text(L10n.viewAnnualReportSub(yearTotal))
                                    .font(.system(size: 11))
                                    .foregroundColor(.white.opacity(0.55))
                            }
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white.opacity(0.55))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    .background(Color.white.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(Color.white.opacity(0.18), lineWidth: 0.5)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
                .padding(.top, 16)
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 20)
        }
    }
}

// MARK: - Motifs (procedural textures for persona backgrounds)

struct PersonaMotif: View {
    let id: PersonaID

    var body: some View {
        GeometryReader { geo in
            Canvas { ctx, size in
                switch id {
                case .nightOwl:    drawStars(ctx: ctx, size: size)
                case .foodie:      drawCircles(ctx: ctx, size: size)
                case .parent:      drawHearts(ctx: ctx, size: size)
                case .wanderer:    drawGrid(ctx: ctx, size: size)
                case .hoarder:     drawPixels(ctx: ctx, size: size)
                case .minimalist:  drawLines(ctx: ctx, size: size)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .opacity(id == .parent ? 0.22 : 0.42)
        }
    }

    private func drawStars(ctx: GraphicsContext, size: CGSize) {
        for i in 0..<40 {
            let x = CGFloat((i * 53 + 17) % Int(size.width))
            let y = CGFloat((i * 73 + 31) % Int(size.height))
            let r: CGFloat = (i % 5 == 0) ? 1.6 : 0.8
            let rect = CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)
            ctx.fill(Path(ellipseIn: rect), with: .color(.white.opacity(0.3 + Double(i % 5) * 0.12)))
        }
    }
    private func drawCircles(ctx: GraphicsContext, size: CGSize) {
        for i in 0..<10 {
            let x = CGFloat((i * 83 + 41) % Int(size.width))
            let y = CGFloat((i * 61 + 23) % Int(size.height))
            let r: CGFloat = 20 + CGFloat(i % 5) * 12
            let rect = CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)
            ctx.stroke(Path(ellipseIn: rect), with: .color(.white.opacity(0.28)), lineWidth: 0.7)
        }
    }
    private func drawHearts(ctx: GraphicsContext, size: CGSize) {
        for i in 0..<14 {
            let x = CGFloat((i * 63 + 20) % Int(size.width))
            let y = CGFloat((i * 71 + 40) % Int(size.height))
            let s: CGFloat = 4 + CGFloat(i % 4) * 3
            let rect = CGRect(x: x - s, y: y - s, width: s * 2, height: s * 2)
            ctx.fill(Path(ellipseIn: rect), with: .color(.white))
        }
    }
    private func drawGrid(ctx: GraphicsContext, size: CGSize) {
        var hlines = Path()
        for i in 0..<Int(size.height / 34) + 1 {
            hlines.move(to: CGPoint(x: 0, y: CGFloat(i) * 34))
            hlines.addLine(to: CGPoint(x: size.width, y: CGFloat(i) * 34))
        }
        ctx.stroke(hlines, with: .color(.white.opacity(0.32)), lineWidth: 0.5)
        var vlines = Path()
        for i in 0..<Int(size.width / 34) + 1 {
            vlines.move(to: CGPoint(x: CGFloat(i) * 34, y: 0))
            vlines.addLine(to: CGPoint(x: CGFloat(i) * 34, y: size.height))
        }
        ctx.stroke(vlines, with: .color(.white.opacity(0.32)), lineWidth: 0.5)
    }
    private func drawPixels(ctx: GraphicsContext, size: CGSize) {
        for i in 0..<80 {
            let x = CGFloat((i * 29) % Int(size.width))
            let y = CGFloat((i * 41) % Int(size.height))
            let s: CGFloat = 3 + CGFloat(i % 3)
            let rect = CGRect(x: x, y: y, width: s, height: s)
            ctx.fill(Path(rect), with: .color(.white.opacity(0.3 + Double(i % 4) * 0.15)))
        }
    }
    private func drawLines(ctx: GraphicsContext, size: CGSize) {
        for i in 0..<30 {
            var p = Path()
            p.move(to: CGPoint(x: -20 + CGFloat(i) * 20, y: 0))
            p.addLine(to: CGPoint(x: -120 + CGFloat(i) * 20, y: size.height))
            ctx.stroke(p, with: .color(.white.opacity(0.45)), lineWidth: 0.4)
        }
    }
}

// MARK: - Trend Card (7-day bars + hour histogram)

struct TrendCard: View {
    let weeklyTrends: [WeeklyTrendSlice]
    let initialWeekIndex: Int
    let monthYearKey: String

    @State private var tab: Tab = .week
    @State private var weekIndex: Int = 0
    enum Tab: String { case week, hour }

    private var boundedWeekIndex: Int {
        guard !weeklyTrends.isEmpty else { return 0 }
        return min(max(weekIndex, 0), weeklyTrends.count - 1)
    }

    private var currentWeek: WeeklyTrendSlice {
        if weeklyTrends.isEmpty {
            return WeeklyTrendSlice(
                id: 0,
                start: Date(),
                end: Date(),
                counts: Array(repeating: 0, count: 7),
                total: 0,
                deltaPct: 0,
                topWeekday: 0,
                hourHistogram: Array(repeating: 0, count: 24),
                peakHour: 0,
                peakHourPct: 0
            )
        }
        return weeklyTrends[boundedWeekIndex]
    }

    private var canPrevWeek: Bool { boundedWeekIndex > 0 }
    private var canNextWeek: Bool { boundedWeekIndex < weeklyTrends.count - 1 }

    private var weekRangeLabel: String {
        let cal = Calendar.current
        let m1 = cal.component(.month, from: currentWeek.start)
        let d1 = cal.component(.day, from: currentWeek.start)
        let m2 = cal.component(.month, from: currentWeek.end)
        let d2 = cal.component(.day, from: currentWeek.end)
        if L10n.isEn {
            return "\(L10n.monthLabel(m1)) \(d1) - \(L10n.monthLabel(m2)) \(d2)"
        }
        return "\(m1)/\(d1) - \(m2)/\(d2)"
    }

    private var topDayLabel: String {
        let zh = ["周一", "周二", "周三", "周四", "周五", "周六", "周日"]
        let en = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
        let i = min(max(currentWeek.topWeekday, 0), 6)
        return L10n.isEn ? en[i] : zh[i]
    }

    private func shiftWeek(by delta: Int) {
        let target = boundedWeekIndex + delta
        guard target >= 0 && target < weeklyTrends.count else { return }
        withAnimation(.easeOut(duration: 0.2)) { weekIndex = target }
    }

    private var weekSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 18)
            .onEnded { value in
                let mostlyHorizontal = abs(value.translation.width) > abs(value.translation.height) * 1.2
                guard mostlyHorizontal else { return }
                if value.translation.width > 35 {
                    shiftWeek(by: -1)
                } else if value.translation.width < -35 {
                    shiftWeek(by: 1)
                }
            }
    }

    var body: some View {
        InsightsCard {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.insightsTrendTitle)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(InsightsTheme.ink)
                    Text("\(weekRangeLabel) · \(L10n.isEn ? "\(currentWeek.total) photos" : "\(currentWeek.total) 张")")
                        .font(.system(size: 12))
                        .foregroundColor(InsightsTheme.ink3)
                }
                Spacer()
                segmentedTabs
            }
            .padding(.bottom, 14)

            Group {
                if tab == .week {
                    Week7Bars(data: currentWeek.counts, highlightIndex: currentWeek.topWeekday)
                    HStack {
                        Text(L10n.isEn ? "\(topDayLabel) is the busiest day" : "\(topDayLabel)拍得最多")
                            .font(.system(size: 12))
                            .foregroundColor(InsightsTheme.ink3)
                        Spacer()
                        HStack(spacing: 3) {
                            Image(systemName: currentWeek.deltaPct >= 0 ? "arrow.up" : "arrow.down")
                                .font(.system(size: 10, weight: .semibold))
                            Text(currentWeek.deltaPct >= 0 ? L10n.insightsTrendDelta(currentWeek.deltaPct) : (L10n.isEn ? "\(currentWeek.deltaPct)% vs last week" : "较上周 \(currentWeek.deltaPct)%"))
                                .font(.system(size: 12))
                        }
                        .foregroundColor(currentWeek.deltaPct >= 0 ? InsightsTheme.greenOK : InsightsTheme.ink3)
                    }
                    .padding(.top, 12)
                    weekSwitcher
                        .padding(.top, 8)
                } else {
                    HourHistogram(data: currentWeek.hourHistogram)
                    Text(L10n.insightsPeakHourInsight(currentWeek.peakHour, currentWeek.peakHourPct))
                        .font(.system(size: 12.5))
                        .foregroundColor(InsightsTheme.accentInk)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(InsightsTheme.accentSoft)
                        .cornerRadius(10)
                        .padding(.top, 12)
                    weekSwitcher
                        .padding(.top, 8)
                }
            }
            .contentShape(Rectangle())
            .gesture(weekSwipeGesture)
        }
        .onAppear {
            weekIndex = min(max(initialWeekIndex, 0), max(weeklyTrends.count - 1, 0))
        }
        .onChange(of: monthYearKey) { _ in
            weekIndex = min(max(initialWeekIndex, 0), max(weeklyTrends.count - 1, 0))
            tab = .week
        }
    }

    private var segmentedTabs: some View {
        HStack(spacing: 0) {
            ForEach([Tab.week, Tab.hour], id: \.self) { t in
                let on = t == tab
                let label = t == .week ? L10n.insightsTrendTab7d : L10n.insightsTrendTabHour
                Text(label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(on ? InsightsTheme.ink : InsightsTheme.ink3)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(on ? Color.white : Color.clear)
                    .cornerRadius(7)
                    .shadow(color: on ? .black.opacity(0.06) : .clear, radius: 1, y: 1)
                    .onTapGesture {
                        withAnimation(.easeOut(duration: 0.2)) { tab = t }
                    }
            }
        }
        .padding(2)
        .background(InsightsTheme.chipBg)
        .cornerRadius(9)
    }

    private var weekSwitcher: some View {
        HStack(spacing: 8) {
            Button {
                withAnimation(.easeOut(duration: 0.2)) { weekIndex = max(0, boundedWeekIndex - 1) }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(canPrevWeek ? InsightsTheme.ink2 : InsightsTheme.ink4)
                    .frame(width: 24, height: 24)
                    .background(InsightsTheme.chipBg)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(!canPrevWeek)

            Spacer()
            Text(L10n.isEn ? "Swipe left/right to switch week" : "左右滑动切换周")
                .font(.system(size: 11))
                .foregroundColor(InsightsTheme.ink4)
            Spacer()

            Button {
                withAnimation(.easeOut(duration: 0.2)) { weekIndex = min(weeklyTrends.count - 1, boundedWeekIndex + 1) }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(canNextWeek ? InsightsTheme.ink2 : InsightsTheme.ink4)
                    .frame(width: 24, height: 24)
                    .background(InsightsTheme.chipBg)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(!canNextWeek)
        }
    }
}

// MARK: - Content mix card

struct ContentMixCard: View {
    let slices: [ContentMixSlice]
    let topLabel: String
    let topPct: Int

    var body: some View {
        InsightsCard {
            Text(L10n.insightsMixTitle)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(InsightsTheme.ink)
            Text(L10n.insightsMixSub)
                .font(.system(size: 12))
                .foregroundColor(InsightsTheme.ink3)
                .padding(.bottom, 14)

            HStack(alignment: .center, spacing: 18) {
                ContentMixDonut(slices: slices, centerLabel: topLabel, centerSub: "\(topPct)%")
                DonutLegend(slices: slices)
            }
        }
    }
}

// MARK: - Screenshot source card

struct ScreenshotInsightCard: View {
    let total: Int
    let unusedPct: Int
    let sources: [ScreenshotSource]

    var body: some View {
        let maxV = max(1, sources.map(\.pct).max() ?? 1)
        InsightsCard(background: InsightsTheme.screenshotCardBg) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(L10n.insightsScreenshotTitle)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(InsightsTheme.ink)
                Text(L10n.insightsScreenshotBadge)
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(0.2)
                    .foregroundColor(Color(hex: "2f69b5"))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(Color(hex: "e5efff"))
                    .clipShape(Capsule())
            }
            Text(L10n.insightsScreenshotSub(total, unusedPct))
                .font(.system(size: 12))
                .foregroundColor(InsightsTheme.ink3)
                .padding(.bottom, 14)

            VStack(spacing: 10) {
                ForEach(sources) { s in
                    HStack(spacing: 10) {
                        Text(s.app)
                            .font(.system(size: 13))
                            .foregroundColor(InsightsTheme.ink)
                            .frame(width: 56, alignment: .leading)
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(InsightsTheme.chipBg)
                                    .frame(height: 6)
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(
                                        LinearGradient(
                                            colors: [Color(hex: "63a4ff"), Color(hex: "4b8be8")],
                                            startPoint: .leading, endPoint: .trailing)
                                    )
                                    .frame(width: geo.size.width * CGFloat(s.pct) / CGFloat(maxV),
                                           height: 6)
                                    .animation(.easeOut(duration: 0.9), value: s.pct)
                            }
                        }
                        .frame(height: 6)
                        Text("\(s.pct)%")
                            .font(.system(size: 12, design: .rounded))
                            .monospacedDigit()
                            .foregroundColor(InsightsTheme.ink3)
                            .frame(width: 34, alignment: .trailing)
                    }
                }
            }
        }
    }
}

// MARK: - Space release card

struct SpaceReleaseCard: View {
    let libraryGB: Double
    let releasableGB: Double
    let categories: [SpaceCategory]
    var onCleanup: () -> Void

    var body: some View {
        InsightsCard(padding: 0) {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(L10n.insightsReleaseLabel)
                                .font(.system(size: 13))
                                .foregroundColor(InsightsTheme.ink3)
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text(formattedGB(releasableGB))
                                    .font(.system(size: 36, weight: .bold, design: .rounded))
                                    .monospacedDigit()
                                    .tracking(-1)
                                    .foregroundColor(InsightsTheme.ink)
                                Text("GB")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(InsightsTheme.ink2)
                            }
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(L10n.insightsLibrarySize)
                                .font(.system(size: 11))
                                .foregroundColor(InsightsTheme.ink3)
                            HStack(alignment: .firstTextBaseline, spacing: 2) {
                                Text(formattedGB(libraryGB))
                                    .font(.system(size: 13, weight: .medium, design: .rounded))
                                    .monospacedDigit()
                                    .foregroundColor(InsightsTheme.ink)
                                Text("GB")
                                    .font(.system(size: 11))
                                    .foregroundColor(InsightsTheme.ink3)
                            }
                        }
                    }

                    // Segment bar
                    HStack(spacing: 0) {
                        ForEach(categories) { c in
                            Rectangle()
                                .fill(c.tint)
                                .frame(width: nil)
                                .frame(maxWidth: .infinity)
                                .scaleEffect(x: CGFloat(c.sizeGB / max(0.01, releasableGB)),
                                             y: 1, anchor: .leading)
                        }
                    }
                    .frame(height: 6)
                    .background(InsightsTheme.chipBg)
                    .clipShape(RoundedRectangle(cornerRadius: 3))

                    VStack(spacing: 10) {
                        ForEach(categories) { c in
                            HStack(spacing: 10) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(c.tint)
                                    .frame(width: 10, height: 10)
                                Text(c.label)
                                    .font(.system(size: 14))
                                    .foregroundColor(InsightsTheme.ink)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Text("\(c.count.formatted())")
                                    .font(.system(size: 12, design: .rounded))
                                    .monospacedDigit()
                                    .foregroundColor(InsightsTheme.ink3)
                                Text(formattedGB(c.sizeGB) + " GB")
                                    .font(.system(size: 13, weight: .medium, design: .rounded))
                                    .monospacedDigit()
                                    .foregroundColor(InsightsTheme.ink)
                                    .frame(width: 56, alignment: .trailing)
                            }
                        }
                    }
                    .padding(.top, 4)
                }
                .padding(18)

                Button(action: onCleanup) {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                        Text(L10n.insightsReleaseCTA(formattedGB(releasableGB) + " GB"))
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .foregroundColor(InsightsTheme.ctaTextOnInk)
                    .padding(.vertical, 14)
                    .background(InsightsTheme.ink)
                    .cornerRadius(14)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 14)
                .padding(.bottom, 14)
            }
        }
    }

    private func formattedGB(_ v: Double) -> String {
        String(format: v < 10 ? "%.1f" : "%.0f", v)
    }
}

// MARK: - AI suggestion card

struct AISuggestionCard: View {
    let count: Int
    let sizeLabel: String
    var onNow: () -> Void = {}
    var onLater: () -> Void = {}

    var body: some View {
        InsightsCard(background: InsightsTheme.accentSoft) {
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(LinearGradient(colors: [Color(hex: "ffb168"), Color(hex: "ff7d45")],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 26, height: 26)
                    Image(systemName: "sparkles").font(.system(size: 13)).foregroundColor(.white)
                }
                Text(L10n.insightsAIBadge)
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(0.5)
                    .foregroundColor(InsightsTheme.accentInk)
                    .textCase(.uppercase)
            }
            .padding(.bottom, 8)

            Text(L10n.insightsAISuggestion(count, sizeLabel))
                .font(.system(size: 15))
                .foregroundColor(InsightsTheme.ink)
                .lineSpacing(3)
                .padding(.bottom, 12)

            HStack(spacing: 8) {
                Button(action: onNow) {
                    Text(L10n.insightsAIActionNow)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(InsightsTheme.ink)
                        .cornerRadius(12)
                }
                .buttonStyle(.plain)
                Button(action: onLater) {
                    Text(L10n.insightsAIActionLater)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(InsightsTheme.ink2)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 11)
                        .background(InsightsTheme.chipBg)
                        .cornerRadius(12)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
