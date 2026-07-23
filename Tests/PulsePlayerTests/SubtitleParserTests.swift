import Foundation
import Testing
@testable import PulsePlayer

@Suite("Subtitle parsers")
struct SubtitleParserTests {
    @Test func parseSRTBasic() throws {
        let srt = """
        1
        00:00:01,000 --> 00:00:04,000
        Hello world

        2
        00:00:05,500 --> 00:00:07,000
        Second line
        """
        let cues = try SRTParser.parse(srt)
        #expect(cues.count == 2)
        #expect(cues[0].start == 1)
        #expect(cues[0].end == 4)
        #expect(cues[0].text == "Hello world")
        #expect(cues[1].start == 5.5)
        #expect(cues[1].text == "Second line")
    }

    @Test func parseVTTBasic() throws {
        let vtt = """
        WEBVTT

        00:00:01.000 --> 00:00:03.000
        First cue

        cue2
        00:00:04.000 --> 00:00:05.000
        Second <b>cue</b>
        """
        let cues = try VTTParser.parse(vtt)
        #expect(cues.count == 2)
        #expect(cues[0].text == "First cue")
        #expect(cues[1].text == "Second cue")
    }

    @Test func presenterRespectsOffset() throws {
        let track = SubtitleTrack(
            format: .srt,
            offset: -1,
            cues: [SubtitleCue(start: 2, end: 4, text: "Hi")]
        )
        // media 3 + offset -1 = 2 → active
        #expect(SubtitlePresenter.activeText(in: track, mediaTime: 3) == "Hi")
        // media 2 + offset -1 = 1 → inactive
        #expect(SubtitlePresenter.activeText(in: track, mediaTime: 2) == nil)
    }

    @Test func presenterReturnsAllOverlappingCuesInStartOrder() {
        var track = SubtitleTrack(
            format: .vtt,
            cues: [
                SubtitleCue(start: 8, end: 9, text: "late"),
                SubtitleCue(start: 0, end: 10, text: "long"),
                SubtitleCue(start: 4, end: 6, text: "middle"),
            ]
        )
        #expect(
            SubtitlePresenter.activeText(in: track, mediaTime: 5)
                == "long\nmiddle"
        )

        track.cues = [
            SubtitleCue(start: 1, end: 3, text: "replacement"),
        ]
        #expect(
            SubtitlePresenter.activeText(in: track, mediaTime: 2)
                == "replacement"
        )
        #expect(SubtitlePresenter.activeText(in: track, mediaTime: 5) == nil)
    }

    @Test func detectFormat() {
        #expect(SubtitleFormat.detect(from: "WEBVTT\n\n") == .vtt)
        #expect(SubtitleFormat.detect(from: "1\n00:00:01,000 --> 00:00:02,000\nHi") == .srt)
    }

    @Test @MainActor
    func sessionSelectsSubtitleText() async throws {
        let engine = MockPlayerEngine()
        let deps = PlayerDependencies.testing(engine: { engine })
        var config = PlayerConfiguration.default
        config.updatesNowPlayingInfo = false
        let session = PlayerSession(configuration: config, dependencies: deps)
        await session.load(MediaSource(url: URL(string: "https://example.com/v.mp4")!))

        let srt = """
        1
        00:00:00,000 --> 00:00:10,000
        Hello
        """
        _ = try session.addSubtitle(content: srt, id: "en", languageCode: "en", format: .srt)
        engine.advanceTime(to: 1)
        #expect(session.currentSubtitleText == "Hello")
        session.selectSubtitle(id: nil)
        #expect(session.currentSubtitleText == nil)
        session.invalidate()
    }
}
