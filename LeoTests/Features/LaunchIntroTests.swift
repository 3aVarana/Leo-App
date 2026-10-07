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
        #expect(LaunchIntro.exit(reduceMotion: false, hasTarget: true) == .move)
        #expect(LaunchIntro.exit(reduceMotion: true, hasTarget: true) == .fade)
        #expect(LaunchIntro.exit(reduceMotion: false, hasTarget: false) == .fade)
        #expect(LaunchIntro.exit(reduceMotion: true, hasTarget: false) == .fade)
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
