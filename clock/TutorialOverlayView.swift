import SwiftUI

struct TutorialOverlayView: View {
    @AppStorage("appTheme") private var currentTheme: AppTheme = .sage
    @AppStorage("is24HourClock") private var is24HourClock: Bool = true
    @Binding var isPresented: Bool
    @State private var step = 0

    private struct TutorialStep {
        let title: String
        let description: String
        let icon: String
    }

    private var steps: [TutorialStep] {
        var s: [TutorialStep] = []
        if !is24HourClock {
            s.append(TutorialStep(
                title: "The Inner Ring",
                description: "The smaller ring represents AM (Midnight to Noon). Notice the sun icon at the top.",
                icon: "sun.max.fill"
            ))
            s.append(TutorialStep(
                title: "The Outer Ring",
                description: "The larger ring represents PM (Noon to Midnight). Notice the moon icon at the top.",
                icon: "moon.fill"
            ))
            s.append(TutorialStep(
                title: "Dynamic Focus",
                description: "Haiku automatically dims the inactive part of your day, so you can focus on the present.",
                icon: "sparkles"
            ))
        }
        s.append(TutorialStep(
            title: "Add Tasks",
            description: "Tap the '+' at the top right to start filling your day with intention.",
            icon: "plus.circle.fill"
        ))
        return s
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()

            VStack(spacing: 30) {
                Spacer()

                if step < steps.count {
                    let current = steps[step]
                    tutorialStep(title: current.title, description: current.description, icon: current.icon)
                }

                Spacer()

                Button(action: {
                    if step < steps.count - 1 {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            step += 1
                            AnalyticsManager.shared.capture("tutorial_step_completed", properties: ["step": step])
                        }
                    } else {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isPresented = false
                            AnalyticsManager.shared.capture("tutorial_completed")
                        }
                    }
                }) {
                    Text(step < steps.count - 1 ? "Next" : "Got it")
                        .font(.system(size: 18, weight: .bold, design: .serif))
                        .foregroundStyle(currentTheme.bg)
                        .frame(width: 200, height: 50)
                        .background(currentTheme.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 15))
                }
                .padding(.bottom, 50)
            }
            .padding(40)
        }
        .onAppear {
            AnalyticsManager.shared.capture("tutorial_started")
        }
    }
    
    @ViewBuilder
    private func tutorialStep(title: String, description: String, icon: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: icon)
                .font(.system(size: 60))
                .foregroundStyle(currentTheme.accent)
                .shadow(color: currentTheme.accent.opacity(0.5), radius: 10)
            
            Text(title)
                .font(.system(size: 24, weight: .bold, design: .serif))
                .foregroundStyle(.white)
                .tracking(2)
            
            Text(description)
                .font(.system(size: 16, design: .serif))
                .foregroundStyle(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .lineSpacing(6)
        }
        .id(step) // Key for smooth transition
        .transition(.asymmetric(
            insertion: .opacity.combined(with: .scale(scale: 0.95)).combined(with: .offset(x: 20)),
            removal: .opacity.combined(with: .offset(x: -20))
        ))
    }
}
