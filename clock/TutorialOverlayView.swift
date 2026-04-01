import SwiftUI

struct TutorialOverlayView: View {
    @AppStorage("appTheme") private var currentTheme: AppTheme = .sage
    @AppStorage("is24HourClock") private var is24HourClock: Bool = true
    @Binding var isPresented: Bool

    @State private var step = 0
    @State private var glowPulse = false
    @State private var focusPhase = false  // false = AM time, true = PM time (Dynamic Focus step)

    // Mock tasks: one AM, one PM so both rings are populated
    private let mockTasks = [
        ClockTask(title: "Deep Work",  startMinutes: 9 * 60,  endMinutes: 11 * 60, color: Color(red: 0.75, green: 0.55, blue: 0.45)),
        ClockTask(title: "Flow",       startMinutes: 14 * 60, endMinutes: 16 * 60, color: Color(red: 0.45, green: 0.65, blue: 0.85)),
    ]

    private enum RingHighlight { case am, pm, none }

    private struct Step {
        let title: String
        let description: String
        let ring: RingHighlight
    }

    private var steps: [Step] {
        var s: [Step] = []
        if !is24HourClock {
            s.append(Step(
                title: "The Inner Ring",
                description: "The smaller ring is AM — midnight to noon. Your morning lives here.",
                ring: .am
            ))
            s.append(Step(
                title: "The Outer Ring",
                description: "The larger ring is PM — noon to midnight. Your afternoon and evening live here.",
                ring: .pm
            ))
            s.append(Step(
                title: "Dynamic Focus",
                description: "The active half of your day stays bright. The other half dims — so you stay anchored to now.",
                ring: .none
            ))
        }
        s.append(Step(
            title: "Add Your First Task",
            description: "Tap the '+' at the top right to start filling your day.",
            ring: .none
        ))
        return s
    }

    private var isDynamicFocusStep: Bool {
        step < steps.count && steps[step].title == "Dynamic Focus"
    }

    // Clock time drives the dynamic focus dimming effect built into StaticClockView
    private var clockHour: Int {
        if isDynamicFocusStep { return focusPhase ? 15 : 9 }
        if step < steps.count && steps[step].ring == .pm { return 15 }
        return 10
    }

    private var clockDate: Date {
        Calendar.current.date(bySettingHour: clockHour, minute: 0, second: 0, of: Date()) ?? Date()
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.82).ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Clock + ring highlight overlay
                ZStack {
                    StaticClockView(
                        now: clockDate,
                        tasks: mockTasks,
                        is24HourClock: false,
                        theme: currentTheme,
                        showHands: true,
                        showText: true,
                        showCenterText: false,
                        animationProgress: 1.0
                    )

                    if step < steps.count && steps[step].ring != .none {
                        RingHighlightOverlay(
                            isPM: steps[step].ring == .pm,
                            glowPulse: glowPulse,
                            theme: currentTheme
                        )
                    }
                }
                .frame(width: 270, height: 270)
                .animation(.easeInOut(duration: 1.4), value: clockHour)

                // Text panel
                if step < steps.count {
                    VStack(spacing: 10) {
                        Text(steps[step].title)
                            .font(.system(size: 22, weight: .bold, design: .serif))
                            .foregroundStyle(.white)
                            .tracking(1)

                        Text(steps[step].description)
                            .font(.system(size: 15, design: .serif))
                            .foregroundStyle(.white.opacity(0.72))
                            .multilineTextAlignment(.center)
                            .lineSpacing(5)
                            .padding(.horizontal, 40)
                    }
                    .id(step)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .offset(y: 12)),
                        removal: .opacity.combined(with: .offset(y: -8))
                    ))
                    .padding(.top, 32)
                }

                Spacer()

                Button(action: advance) {
                    Text(step < steps.count - 1 ? "Next" : "Got it")
                        .font(.system(size: 18, weight: .bold, design: .serif))
                        .foregroundStyle(currentTheme.bg)
                        .frame(width: 200, height: 50)
                        .background(currentTheme.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 15))
                }
                .padding(.bottom, 50)
            }
        }
        .onAppear {
            AnalyticsManager.shared.capture("tutorial_started")
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                glowPulse = true
            }
        }
        // Drives the Dynamic Focus animation loop — auto-cancels when step changes
        .task(id: step) {
            guard isDynamicFocusStep else {
                focusPhase = false
                return
            }
            while !Task.isCancelled {
                withAnimation(.easeInOut(duration: 1.4)) { focusPhase = true }
                try? await Task.sleep(for: .seconds(1.8))
                guard !Task.isCancelled else { break }
                withAnimation(.easeInOut(duration: 1.4)) { focusPhase = false }
                try? await Task.sleep(for: .seconds(1.8))
            }
        }
    }

    private func advance() {
        if step < steps.count - 1 {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                step += 1
            }
            AnalyticsManager.shared.capture("tutorial_step_completed", properties: ["step": step])
        } else {
            withAnimation(.easeInOut(duration: 0.3)) {
                isPresented = false
            }
            AnalyticsManager.shared.capture("tutorial_completed")
        }
    }
}

// MARK: - Ring highlight overlay

/// Draws a pulsing glow ring on top of the clock at the AM or PM ring position,
/// using the same proportional geometry as StaticClockView (12-hour mode).
private struct RingHighlightOverlay: View {
    let isPM: Bool
    let glowPulse: Bool
    let theme: AppTheme

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let radius = size / 2
            // Must match StaticClockView's 12-hour proportions exactly
            let ringWidth = size * 0.06
            let ringSpacing = size * 0.015
            let pmRingRadius = radius - ringWidth / 2
            let amRingRadius = pmRingRadius - ringWidth - ringSpacing

            let highlightRadius = isPM ? pmRingRadius : amRingRadius

            ZStack {
                // Outer bracket
                Circle()
                    .stroke(theme.accent.opacity(0.5), lineWidth: 1)
                    .frame(width: (highlightRadius + ringWidth / 2 + 5) * 2,
                           height: (highlightRadius + ringWidth / 2 + 5) * 2)

                // Inner bracket
                Circle()
                    .stroke(theme.accent.opacity(0.5), lineWidth: 1)
                    .frame(width: (highlightRadius - ringWidth / 2 - 5) * 2,
                           height: (highlightRadius - ringWidth / 2 - 5) * 2)

                // Pulsing glow
                Circle()
                    .stroke(theme.accent.opacity(glowPulse ? 0.7 : 0.25), lineWidth: ringWidth + 8)
                    .frame(width: highlightRadius * 2, height: highlightRadius * 2)
                    .blur(radius: 8)
            }
            .position(x: geo.size.width / 2, y: geo.size.height / 2)
        }
    }
}
