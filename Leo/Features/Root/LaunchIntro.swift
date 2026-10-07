import SwiftUI

// The launch intro of docs/Leo-Launch-Screen-Plan.md, section 3: it starts on the launch screen's
// frame, a centered "Leo", and hands over to the first screen. On Welcome the wordmark moves into
// the header; on other screens it fades out. Everything else rises into place as one block.

enum LaunchIntro {
    /// Set once the intro has started, so it plays on cold launch only.
    static var hasPlayed = false

    /// All the times and curves in one place.
    enum Timing {
        /// The launch frame stays still before the move.
        static let hold = 0.3
        static let moveDuration = 0.48
        /// How long after the move begins the page starts to rise.
        static let pageDelay = 0.2
        static let pageDuration = 0.48
        /// How far below its place the page starts.
        static let rise: CGFloat = 24
        /// With Reduce Motion: the wordmark and the page cross-fade.
        static let reducedMotionFade = 0.2

        /// When the page finishes rising, from the first frame. The last thing to move.
        static var pageEnd: Double {
            hold + pageDelay + pageDuration
        }

        /// When the header wordmark takes over from the moving one, and taps are enabled. The
        /// moving wordmark waits at its place until the page settles under it, so the swap is exact.
        static var swap: Double {
            pageEnd
        }

        /// How long the intro runs after the hold.
        static var playing: Double {
            swap - hold
        }

        static let moveCurve = Animation.timingCurve(0.65, 0, 0.25, 1, duration: moveDuration)
        static let pageCurve = Animation.timingCurve(0.2, 0.7, 0.2, 1, duration: pageDuration).delay(pageDelay)
        static let reducedMotionCurve = Animation.easeInOut(duration: reducedMotionFade)
    }

    enum Phase {
        /// The first frame: the launch screen again, with the page hidden.
        case launch
        /// The wordmark moves or fades, and the page rises.
        case playing
        /// Everything at rest.
        case done

        var isPageShown: Bool {
            self != .launch
        }

        /// Taps wait for the swap (L3 of the plan).
        var isPageInteractive: Bool {
            self == .done
        }

        var isRunning: Bool {
            self != .done
        }
    }

    /// Where the centered wordmark ends up, and how much it shrinks, to land exactly on the
    /// header wordmark.
    struct WordmarkMove: Equatable {
        var center: CGPoint
        var scale: CGFloat
    }

    /// - Parameters:
    ///   - header: The header wordmark's frame, measured while the page is `Timing.rise` below its place.
    ///   - overlayHeight: The centered wordmark's height before scaling.
    ///
    /// The scale is the ratio of the two text heights, so it follows Dynamic Type for the header.
    static func wordmarkMove(header: CGRect, overlayHeight: CGFloat) -> WordmarkMove {
        WordmarkMove(
            center: CGPoint(x: header.midX, y: header.midY - Timing.rise),
            scale: header.height / overlayHeight,
        )
    }
}

// MARK: - Header wordmark

/// The header wordmark's frame in the window, published by `WelcomeView`. Screens without one
/// publish nothing, and the centered wordmark fades out instead.
struct LaunchWordmarkFrame: PreferenceKey {
    static let defaultValue: CGRect? = nil

    static func reduce(value: inout CGRect?, nextValue: () -> CGRect?) {
        value = value ?? nextValue()
    }
}

extension EnvironmentValues {
    /// Whether the intro is running. The header wordmark stays hidden, in its place, until it ends.
    @Entry var isLaunchIntroRunning = false
}

extension View {
    /// Marks this view as the place the launch wordmark moves to, and hides it while the intro runs.
    func launchWordmarkTarget() -> some View {
        modifier(LaunchWordmarkTargetModifier())
    }

    /// Plays the launch intro over this view, the first time it's shown after the app launches.
    func launchIntro() -> some View {
        modifier(LaunchIntroModifier())
    }
}

private struct LaunchWordmarkTargetModifier: ViewModifier {
    @Environment(\.isLaunchIntroRunning) private var isIntroRunning

    func body(content: Content) -> some View {
        content
            .opacity(isIntroRunning ? 0 : 1)
            .background {
                GeometryReader { proxy in
                    Color.clear.preference(key: LaunchWordmarkFrame.self, value: proxy.frame(in: .global))
                }
            }
    }
}

// MARK: - The intro

struct LaunchIntroModifier: ViewModifier {
    /// `plays: false` freezes the intro at `initialPhase`, for snapshots and previews.
    init(initialPhase: LaunchIntro.Phase? = nil, plays: Bool = true) {
        _phase = State(initialValue: initialPhase ?? (LaunchIntro.hasPlayed ? .done : .launch))
        self.plays = plays
    }

    private let plays: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: LaunchIntro.Phase
    /// The header wordmark's frame, kept from the first frame, while nothing has moved yet.
    @State private var headerFrame: CGRect?
    @State private var overlayHeight: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .environment(\.isLaunchIntroRunning, phase.isRunning)
            .opacity(phase.isPageShown ? 1 : 0)
            .visualEffect { [phase, reduceMotion] view, _ in
                view.offset(y: phase.isPageShown || reduceMotion ? 0 : LaunchIntro.Timing.rise)
            }
            .animation(
                reduceMotion ? LaunchIntro.Timing.reducedMotionCurve : LaunchIntro.Timing.pageCurve,
                value: phase.isPageShown,
            )
            .allowsHitTesting(phase.isPageInteractive)
            .onPreferenceChange(LaunchWordmarkFrame.self) { frame in
                if phase == .launch {
                    headerFrame = frame
                }
            }
            // The ground is always there, so nothing flashes while the page is transparent.
            .background(Color.leoBackground.ignoresSafeArea())
            .overlay {
                if phase.isRunning {
                    wordmark
                }
            }
            .task { await play() }
    }

    private var wordmark: some View {
        GeometryReader { proxy in
            let screen = proxy.frame(in: .global)
            let move = reduceMotion ? nil : headerFrame.flatMap(wordmarkMove)
            let isMoving = phase.isPageShown
            let center = isMoving ? move?.center : nil
            Text(verbatim: "Leo")
                .leoTextStyle(.launchWordmark)
                .foregroundStyle(Color.leoInk)
                .onGeometryChange(for: CGFloat.self, of: \.size.height) { overlayHeight = $0 }
                .scaleEffect(isMoving ? move?.scale ?? 1 : 1)
                .opacity(isMoving && move == nil ? 0 : 1)
                .position(
                    x: (center?.x ?? screen.midX) - screen.minX,
                    y: (center?.y ?? screen.midY) - screen.minY,
                )
                .animation(
                    reduceMotion ? LaunchIntro.Timing.reducedMotionCurve : LaunchIntro.Timing.moveCurve,
                    value: isMoving,
                )
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }

    private func wordmarkMove(for header: CGRect) -> LaunchIntro.WordmarkMove? {
        guard overlayHeight > 0 else { return nil }
        return LaunchIntro.wordmarkMove(header: header, overlayHeight: overlayHeight)
    }

    private func play() async {
        guard plays, phase != .done else { return }
        LaunchIntro.hasPlayed = true
        if phase == .launch {
            guard await sleep(LaunchIntro.Timing.hold) else { return }
            phase = .playing
        }
        let duration = reduceMotion ? LaunchIntro.Timing.reducedMotionFade : LaunchIntro.Timing.playing
        guard await sleep(duration) else { return }
        phase = .done
    }

    /// `false` when the task was cancelled, so a view that goes away doesn't finish the intro.
    private func sleep(_ seconds: Double) async -> Bool {
        await (try? Task.sleep(for: .seconds(seconds))) != nil
    }
}

#Preview("Launch frame") {
    Color.clear.modifier(LaunchIntroModifier(initialPhase: .launch, plays: false))
}
