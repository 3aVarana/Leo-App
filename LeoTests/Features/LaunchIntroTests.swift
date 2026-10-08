@testable import Leo
import SwiftUI
import Testing

@MainActor
struct LaunchIntroTests {
    typealias Timing = LaunchIntro.Timing

    @Test func holdIsShortAndTheMoveStartsAfterIt() {
        #expect(Timing.hold == 0.3)
    }

    /// The page starts rising during the move, and its rise is the last thing to finish.
    @Test func pageRisesWhileTheWordmarkMovesAndFinishesLast() {
        let moveStart = Timing.hold
        let moveEnd = Timing.hold + Timing.moveDuration
        let pageStart = Timing.hold + Timing.pageDelay
        #expect(pageStart > moveStart)
        #expect(pageStart < moveEnd)
        #expect(Timing.pageEnd > moveEnd)
    }

    /// The moving wordmark stays until the page has settled, so the header takes over without a jump.
    @Test func swapWaitsForThePage() {
        #expect(Timing.swap == Timing.pageEnd)
        #expect(Timing.hold + Timing.playing == Timing.swap)
    }

    @Test func pageIsInteractiveOnlyOnceTheIntroIsDone() {
        #expect(!LaunchIntro.Phase.launch.isPageInteractive)
        #expect(!LaunchIntro.Phase.playing.isPageInteractive)
        #expect(LaunchIntro.Phase.done.isPageInteractive)
    }

    @Test func pageIsHiddenOnlyOnTheFirstFrame() {
        #expect(!LaunchIntro.Phase.launch.isPageShown)
        #expect(LaunchIntro.Phase.playing.isPageShown)
        #expect(LaunchIntro.Phase.done.isPageShown)
    }

    @Test func theIntroIsRunningUntilItIsDone() {
        #expect(LaunchIntro.Phase.launch.isRunning)
        #expect(LaunchIntro.Phase.playing.isRunning)
        #expect(!LaunchIntro.Phase.done.isRunning)
    }

    @Test func wordmarkMovesOnlyWhenMotionIsAllowedAndThereIsAHeaderToLandOn() {
        #expect(LaunchIntro.exit(reduceMotion: false, hasTarget: true, headerMoved: false) == .move)
        #expect(LaunchIntro.exit(reduceMotion: true, hasTarget: true, headerMoved: false) == .fade)
        #expect(LaunchIntro.exit(reduceMotion: false, hasTarget: false, headerMoved: false) == .fade)
        #expect(LaunchIntro.exit(reduceMotion: true, hasTarget: false, headerMoved: false) == .fade)
    }

    /// A header that moved after it was measured would be missed, so the wordmark fades instead.
    @Test func wordmarkFadesOnceTheHeaderHasMoved() {
        #expect(LaunchIntro.exit(reduceMotion: false, hasTarget: true, headerMoved: true) == .fade)
    }

    /// The rotating iPad's change arrived about 0.1 s into the move.
    @Test func headerCanBeComparedOnlyBeforeThePageStartsRising() {
        #expect(LaunchIntro.canCompareHeader(sinceMoveBegan: 0))
        #expect(LaunchIntro.canCompareHeader(sinceMoveBegan: 0.11))
        #expect(!LaunchIntro.canCompareHeader(sinceMoveBegan: Timing.pageDelay))
        #expect(!LaunchIntro.canCompareHeader(sinceMoveBegan: 0.4))
    }

    @Test func headerMovedIgnoresSubPixelNoiseOnly() {
        let header = CGRect(x: 305, y: 68.25, width: 33.5, height: 27.5)
        #expect(!LaunchIntro.headerMoved(from: header, to: header))
        #expect(!LaunchIntro.headerMoved(from: header, to: header.offsetBy(dx: 0.2, dy: -0.3)))
        // The iPad rotating after launch moved it 22 points.
        #expect(LaunchIntro.headerMoved(from: header, to: header.offsetBy(dx: 0, dy: -22)))
        #expect(LaunchIntro.headerMoved(from: header, to: header.offsetBy(dx: 10, dy: 0)))
        #expect(LaunchIntro.headerMoved(from: header, to: CGRect(x: 305, y: 68.25, width: 60, height: 50)))
    }

    /// Under Reduce Motion the header is part of the page and fades in with it.
    @Test func headerWordmarkIsHiddenOnlyWhileTheMovingOneStandsInForIt() {
        #expect(LaunchIntro.hidesHeader(phase: .launch, exit: .move))
        #expect(LaunchIntro.hidesHeader(phase: .playing, exit: .move))
        #expect(!LaunchIntro.hidesHeader(phase: .done, exit: .move))
        for phase in [LaunchIntro.Phase.launch, .playing, .done] {
            #expect(!LaunchIntro.hidesHeader(phase: phase, exit: .fade))
        }
    }

    /// 20 / 48 at the default text size.
    @Test func moveScalesToTheHeaderWordmark() {
        let overlayHeight = 48 * 1.371 // Source Serif 4 line height
        let header = CGRect(x: 24, y: 80, width: 33.2, height: 20 * 1.371)
        let move = LaunchIntro.wordmarkMove(header: header, overlayHeight: overlayHeight)
        #expect(abs(move.scale - 20.0 / 48.0) < 0.0001)
    }

    /// The header is measured while the page is still below its place, so the target is the
    /// resting place: the measured center minus the rise.
    @Test func moveLandsWhereTheHeaderWillBeAtRest() {
        let header = CGRect(x: 24, y: 80, width: 40, height: 28)
        let move = LaunchIntro.wordmarkMove(header: header, overlayHeight: 66)
        #expect(move.center == CGPoint(x: 44, y: 94 - Timing.rise))
    }

    /// At accessibility sizes the header is taller, and the wordmark ends up larger, to match.
    @Test func moveFollowsDynamicType() {
        let large = CGRect(x: 24, y: 80, width: 40, height: 28)
        let accessibility = CGRect(x: 24, y: 80, width: 90, height: 62)
        let small = LaunchIntro.wordmarkMove(header: large, overlayHeight: 66).scale
        let big = LaunchIntro.wordmarkMove(header: accessibility, overlayHeight: 66).scale
        #expect(big > small)
        #expect(abs(big * 66 - 62) < 0.0001)
    }
}
