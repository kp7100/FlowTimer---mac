import SwiftUI

struct DoubleWaveShape: Shape {
    var leftProgress: CGFloat
    var rightProgress: CGFloat
    var phase: CGFloat
    
    nonisolated var animatableData: AnimatablePair<AnimatablePair<CGFloat, CGFloat>, CGFloat> {
        get { AnimatablePair(AnimatablePair(leftProgress, rightProgress), phase) }
        set { 
            leftProgress = newValue.first.first
            rightProgress = newValue.first.second
            phase = newValue.second
        }
    }
    
    nonisolated func path(in rect: CGRect) -> Path {
        var path = Path()
        
        let amplitude: CGFloat = 12.0
        let frequency: CGFloat = 1.5
        
        // Base coordinate system extending well past the bounds
        let leftX = leftProgress * (rect.width + 100) - 50
        let rightX = rightProgress * (rect.width + 100) - 50
        
        let steps = 30
        
        // Left edge (top to bottom)
        for i in 0...steps {
            let t = CGFloat(i) / CGFloat(steps)
            let y = rect.height * t
            let wiggle = sin(t * frequency * .pi * 2 + phase + .pi) * amplitude // Anti-phase
            let x = leftX + wiggle
            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        
        // Right edge (bottom to top)
        for i in 0...steps {
            let t = CGFloat(i) / CGFloat(steps)
            let y = rect.height * (1.0 - t)
            let wiggle = sin(t * frequency * .pi * 2 + phase) * amplitude
            let x = rightX + wiggle
            path.addLine(to: CGPoint(x: x, y: y))
        }
        
        path.closeSubpath()
        return path
    }
}

struct FlowModeTransitionModifier: ViewModifier {
    var timerManager: TimerManager
    var isDarkMode: Bool
    
    @State private var isActive = false
    
    // Animation states
    @State private var leftProgress: CGFloat = -0.1
    @State private var rightProgress: CGFloat = -0.1
    @State private var textOpacity: Double = 0.0
    @State private var textOffset: CGFloat = -20.0
    @State private var textScale: CGFloat = 0.97
    @State private var textBlur: CGFloat = 3.0
    @State private var wavePhase: CGFloat = 0.0
    
    @State private var baseTheme: AmbientTheme? = nil
    @State private var disableThemeAnimation = false
    
    @State private var timerScale: CGFloat = 1.0
    @State private var timerOpacity: Double = 1.0
    
    func body(content: Content) -> some View {
        ZStack {
            // BASE LAYER: The actual timer UI
            content
                .scaleEffect(timerScale)
                .opacity(timerOpacity)
                .ambientTheme(baseTheme ?? AmbientTheme.current(for: timerManager.phase, isDarkMode: isDarkMode))
                .transaction { transaction in
                    if disableThemeAnimation {
                        transaction.animation = nil
                    }
                }
            
            // CURTAIN LAYER: Solid Flow Blue with Wavy Edges
            if isActive {
                let flowTheme = AmbientTheme.current(for: .flowExtension, isDarkMode: isDarkMode)
                
                GeometryReader { geo in
                    ZStack {
                        // The physical curtain (DoubleWaveShape)
                        DoubleWaveShape(leftProgress: leftProgress, rightProgress: rightProgress, phase: wavePhase)
                            .fill(AmbientTheme.flowColor(isDarkMode: isDarkMode))
                            // Glow on BOTH edges
                            .shadow(color: flowTheme.primaryColor.opacity(0.8), radius: 15, x: 0, y: 0)
                        
                        // The Hero Text
                        Text("Entering Flow")
                            .font(.system(size: 42, weight: .semibold, design: .rounded))
                            .tracking(1)
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.4)
                            .padding(.horizontal, 24)
                            .shadow(color: .white.opacity(0.15), radius: 2, x: 0, y: 0)
                            .blur(radius: textBlur)
                            .scaleEffect(textScale)
                            .opacity(textOpacity)
                            .offset(x: textOffset)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                            .mask(
                                DoubleWaveShape(leftProgress: leftProgress, rightProgress: rightProgress, phase: wavePhase)
                            )
                    }
                    .frame(width: geo.size.width)
                    .ignoresSafeArea()
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: AmbientTheme.cornerRadius, style: .continuous))
        .onChange(of: timerManager.flowTransitionID) { _, newID in
            guard newID != nil else { return }
            runAnimationSequence()
        }
    }
    
    private func runAnimationSequence() {
        isActive = true
        
        // Initial state
        leftProgress = -0.1
        rightProgress = -0.1
        
        textOpacity = 0.0
        textScale = 0.95
        textBlur = 5.0
        textOffset = -30.0
        wavePhase = 0.0
        
        timerOpacity = 0.85
        timerScale = 0.98
        
        baseTheme = AmbientTheme.current(for: .work, isDarkMode: isDarkMode)
        disableThemeAnimation = true
        
        // 0. Continuous Wiggle Life
        withAnimation(.linear(duration: 1.0).repeatForever(autoreverses: false)) {
            wavePhase = .pi * 4
        }
        
        // 1. Enter Wave (Right Edge sweeps across over 1.35s)
        withAnimation(.easeInOut(duration: 1.35)) {
            rightProgress = 1.1
        }
        
        // Text enters with subtle life
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.30) {
            withAnimation(.easeOut(duration: 0.60)) {
                textOpacity = 1.0
                textScale = 1.0
                textBlur = 0.0
            }
            // Drift (rides the current, finishes exactly as exit wave begins)
            withAnimation(.easeOut(duration: 1.05)) {
                textOffset = 8.0
            }
        }
        
        // Snap underlying theme while mostly covered
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.50) {
            disableThemeAnimation = true
            baseTheme = AmbientTheme.current(for: .flowExtension, isDarkMode: isDarkMode)
        }
        
        // 2. Second Wave (Left Edge) starts IMMEDIATELY (T = 1.35s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.35) {
            withAnimation(.easeInOut(duration: 1.50)) {
                leftProgress = 1.1
                
                // Text travels with the wave (slower than wave, so it gets overtaken)
                textOffset = 180.0
                textOpacity = 0.0
                textBlur = 2.0
                textScale = 1.02
            }
        }
        
        // 3. Reveal timer (T = 2.55s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.55) {
            withAnimation(.easeOut(duration: 0.45)) {
                timerOpacity = 1.0
                timerScale = 1.0
            }
        }
        
        // 4. Cleanup (T = 3.45s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.45) {
            isActive = false
            baseTheme = nil
            disableThemeAnimation = false
        }
    }
}

extension View {
    func flowModeTransition(timerManager: TimerManager, isDarkMode: Bool) -> some View {
        self.modifier(FlowModeTransitionModifier(timerManager: timerManager, isDarkMode: isDarkMode))
    }
}
