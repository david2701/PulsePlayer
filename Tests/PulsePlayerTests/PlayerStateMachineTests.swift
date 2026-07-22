import Testing
@testable import PulsePlayer

@Suite("PlayerStateMachine")
struct PlayerStateMachineTests {
    @Test func loadFromIdle() {
        let t = PlayerStateMachine.transition(status: .idle, event: .load)
        #expect(t == .to(.loading))
    }

    @Test func itemReadyFromLoading() {
        #expect(
            PlayerStateMachine.transition(status: .loading, event: .itemReady) == .to(.ready)
        )
    }

    @Test func autoplayGateFromReady() {
        #expect(
            PlayerStateMachine.transition(status: .ready, event: .autoplayGate) == .to(.playing)
        )
    }

    @Test func playFromReady() {
        #expect(PlayerStateMachine.transition(status: .ready, event: .play) == .to(.playing))
    }

    @Test func bufferEmptyFromPlaying() {
        #expect(
            PlayerStateMachine.transition(status: .playing, event: .bufferEmpty) == .to(.buffering)
        )
    }

    @Test func stallTimeoutFromBuffering() {
        #expect(
            PlayerStateMachine.transition(status: .buffering, event: .stallTimeout) == .to(.stalled)
        )
    }

    @Test func stallTimeoutFromLoadingIsIllegal() {
        #expect(
            PlayerStateMachine.transition(status: .loading, event: .stallTimeout) == .illegal
        )
    }

    @Test func failFromLoading() {
        #expect(PlayerStateMachine.transition(status: .loading, event: .fail) == .to(.failed))
    }

    @Test func retryFromFailed() {
        #expect(PlayerStateMachine.transition(status: .failed, event: .retry) == .to(.loading))
    }

    @Test func didPlayToEndVOD() {
        #expect(
            PlayerStateMachine.transition(
                status: .playing,
                event: .didPlayToEnd,
                isLive: false
            ) == .to(.ended)
        )
    }

    @Test func didPlayToEndLiveStays() {
        #expect(
            PlayerStateMachine.transition(
                status: .playing,
                event: .didPlayToEnd,
                isLive: true
            ) == .stay
        )
    }

    @Test func invalidateIsTerminal() {
        #expect(
            PlayerStateMachine.transition(status: .playing, event: .invalidate) == .to(.invalidated)
        )
        #expect(
            PlayerStateMachine.transition(status: .invalidated, event: .play) == .illegal
        )
    }

    @Test func playFromIdleIllegal() {
        #expect(PlayerStateMachine.transition(status: .idle, event: .play) == .illegal)
    }

    @Test func loopAdvanceFromEnded() {
        #expect(
            PlayerStateMachine.transition(status: .ended, event: .loopAdvance) == .to(.playing)
        )
    }

    @Test func resetToIdle() {
        #expect(PlayerStateMachine.transition(status: .failed, event: .reset) == .to(.idle))
    }
}
