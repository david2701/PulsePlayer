import Testing
@testable import PulsePlayer

@Suite("PlayerEventBus")
@MainActor
struct PlayerEventBusTests {
    @Test func dualSubscribersReceiveSameEvent() async {
        let bus = PlayerEventBus(bufferSize: 8)
        let s1 = bus.makeStream()
        let s2 = bus.makeStream()

        let task1 = Task {
            var it = s1.makeAsyncIterator()
            return await it.next()
        }
        let task2 = Task {
            var it = s2.makeAsyncIterator()
            return await it.next()
        }

        // Yield after subscribers are waiting.
        try? await Task.sleep(for: .milliseconds(20))
        bus.yield(.playbackStarted)

        let e1 = await task1.value
        let e2 = await task2.value
        #expect(e1 == .playbackStarted)
        #expect(e2 == .playbackStarted)
        bus.finish()
    }
}
