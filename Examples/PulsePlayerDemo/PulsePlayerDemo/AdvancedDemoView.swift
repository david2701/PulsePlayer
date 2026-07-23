import PulsePlayer
import SwiftUI

/// Quality, tracks, playlist queue, continue watching, FairPlay wiring.
struct AdvancedDemoView: View {
    @State private var session = Self.makeSession()
    @State private var queue = PlaybackQueue(items: [], autoplayNext: true)
    @State private var message = ""
    @State private var productionEvents: [String] = []
    @State private var certURL = ""
    @State private var licenseURL = ""
    @State private var drmAssetURL = ""
    @State private var contentId = "asset-1"

    private let episodes: [MediaSource] = [
        Self.episode(id: "adv", url: DemoMedia.bipbopAdvanced, title: "1 · Advanced"),
        Self.episode(id: "16x9", url: DemoMedia.bipbop16x9, title: "2 · 16:9"),
        Self.episode(id: "4x3", url: DemoMedia.bipbop4x3, title: "3 · 4:3"),
        Self.episode(id: "basic", url: DemoMedia.bipbopBasic, title: "4 · Basic"),
    ]

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                let h = min(max(geo.size.width * 9 / 16, 240), geo.size.height * 0.40)
                VStack(spacing: 0) {
                    PulsePlayerView(
                        session: session,
                        chrome: .full,
                        theme: .pulse,
                        enableGestures: true
                    )
                    .frame(maxWidth: .infinity)
                    .frame(height: h)
                    .background(Color.black)

                    List {
                        Section("Playlist") {
                            Text("Item \(queue.currentIndex + 1)/\(max(queue.items.count, 1)) · \(queue.current?.title ?? "—")")
                                .font(.subheadline)
                            HStack {
                                Button("Prev") { Task { await queue.previous() } }
                                    .disabled(!queue.hasPrevious)
                                Button("Play queue") { Task { await startQueue() } }
                                Button("Next") { Task { await queue.next() } }
                                    .disabled(!queue.hasNext)
                            }
                            .buttonStyle(.bordered)
                        }

                        Section("Production cockpit") {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    metricChip(
                                        "TTFF",
                                        value: ttffLabel,
                                        color: .cyan
                                    )
                                    metricChip(
                                        "Rebuffers",
                                        value: "\(session.metricsSnapshot.rebufferCount)",
                                        color: session.metricsSnapshot.rebufferCount == 0
                                            ? .green
                                            : .orange
                                    )
                                    metricChip(
                                        "Fallbacks",
                                        value: "\(session.metricsSnapshot.sourceFallbackCount)",
                                        color: .purple
                                    )
                                    metricChip(
                                        "Auth refresh",
                                        value: "\(session.metricsSnapshot.credentialRefreshCount)",
                                        color: .blue
                                    )
                                }
                            }

                            LabeledContent("Playback ID") {
                                Text(String(session.playbackID.uuidString.prefix(8)))
                                    .font(.caption.monospaced())
                            }
                            LabeledContent("Origin strategy") {
                                Text("Primary + \(session.currentSource?.fallbackURLs.count ?? 0) fallbacks")
                            }
                            LabeledContent("Performance budget") {
                                Text("8s TTFF · 3 rebuffers")
                            }
                            LabeledContent("Lifecycle") {
                                Text("Audio + foreground recovery")
                            }

                            if productionEvents.isEmpty {
                                Text("Production events will appear during playback")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else {
                                ForEach(
                                    Array(productionEvents.enumerated()),
                                    id: \.offset
                                ) { _, event in
                                    Label(event, systemImage: "waveform.path.ecg")
                                        .font(.caption)
                                }
                            }
                        }

                        Section("Quality") {
                            Button("Auto") { Task { await session.setQualityAuto() } }
                            ForEach(session.availableQualities) { q in
                                Button {
                                    Task { await session.setQuality(q) }
                                } label: {
                                    HStack {
                                        Text(q.label)
                                        Text("\(q.bandwidth / 1000) kbps")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Spacer()
                                        if session.selectedQualityId == q.id {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                            if session.availableQualities.isEmpty {
                                Text("Load an HLS source to parse ladder")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Section("Tracks") {
                            ForEach(session.availableAudioTracks) { t in
                                Button(t.displayName) {
                                    session.selectAudioTrack(id: t.id)
                                }
                            }
                            ForEach(session.availableTextTracks) { t in
                                Button("\(t.displayName)\(t.isExternal ? " (ext)" : "")") {
                                    session.selectTextTrack(id: t.id)
                                }
                            }
                            if session.availableAudioTracks.isEmpty && session.availableTextTracks.isEmpty {
                                Text("No alternate tracks on this stream")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Section("Continue watching") {
                            if let id = session.currentSource?.id,
                               let pos = session.continueStore.position(for: id)
                            {
                                Text("Saved \(String(format: "%.0fs", pos)) for \(id)")
                                Button("Clear saved position") {
                                    session.continueStore.remove(sourceId: id)
                                }
                            } else {
                                Text("Pause mid-video to save resume point")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Section("FairPlay (real HTTP, not mock)") {
                            Text(fairPlayExplainer)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            TextField("Certificate URL", text: $certURL)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                            TextField("License URL", text: $licenseURL)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                            TextField("Encrypted HLS URL", text: $drmAssetURL)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                            TextField("Content key asset id", text: $contentId)
                                .textInputAutocapitalization(.never)
                            Button("Wire HTTPContentKeyProvider + load") {
                                Task { await loadFairPlay() }
                            }
                            .buttonStyle(.borderedProminent)
                        }

                        if !message.isEmpty {
                            Section("Status") {
                                Text(message)
                                    .font(.footnote)
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Advanced")
            .navigationBarTitleDisplayMode(.inline)
            .task { await startQueue() }
            .task { await observeProductionEvents() }
            .onDisappear {
                queue.saveProgress()
                session.pause()
            }
        }
    }

    private var fairPlayExplainer: String {
        """
        No public free FairPlay stream exists. Real playback needs Apple FPS cert + key server + encrypted HLS.
        Paste your cert/license endpoints (from FairPlay Streaming Server SDK or a multi-DRM vendor). Uses HTTPContentKeyProvider — real network, not a mock CKC.
        """
    }

    private var ttffLabel: String {
        guard let value = session.metricsSnapshot.ttffMilliseconds else {
            return "—"
        }
        return value >= 1_000
            ? String(format: "%.1fs", value / 1_000)
            : String(format: "%.0fms", value)
    }

    private func metricChip(
        _ title: String,
        value: String,
        color: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.weight(.semibold).monospacedDigit())
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(color.opacity(0.14), in: RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(color.opacity(0.28), lineWidth: 1)
        }
    }

    private func startQueue() async {
        queue.setItems(episodes, startAt: 0)
        queue.session = session
        session.playbackQueue = queue
        session.continueWatchingEnabled = true
        await queue.playCurrent()
        message = "Queue playing · qualities load after ready"
    }

    private func loadFairPlay() async {
        guard let cert = URL(string: certURL), let lic = URL(string: licenseURL),
              let asset = URL(string: drmAssetURL), !contentId.isEmpty
        else {
            message = "Fill certificate, license, asset URL and content id"
            return
        }
        let provider = HTTPContentKeyProvider(
            configuration: .init(
                certificateURL: cert,
                licenseURL: lic,
                licenseBody: .jsonBase64SPC
            )
        )
        session.contentKeyProvider = provider
        session.persistableContentKeyStore = try? PersistableContentKeyFileStore()
        let source = MediaSource(
            id: contentId,
            url: asset,
            title: "FairPlay asset",
            contentKeyAssetId: contentId,
            requestsPersistableContentKey: true
        )
        await session.load(source)
        session.play()
        message = "FairPlay provider wired — playback needs valid cert+CKC+encrypted media"
    }

    private func observeProductionEvents() async {
        for await event in session.makeProductionEventStream() {
            productionEvents.insert(productionEventLabel(event), at: 0)
            if productionEvents.count > 6 {
                productionEvents.removeLast(productionEvents.count - 6)
            }
        }
    }

    private func productionEventLabel(_ event: ProductionPlayerEvent) -> String {
        switch event {
        case .credentialRefreshStarted:
            "Credential refresh started"
        case .credentialRefreshSucceeded:
            "Credential refresh succeeded"
        case .credentialRefreshFailed:
            "Credential refresh failed"
        case .sourceFallback(let from, let to):
            "Origin fallback \(from + 1) → \(to + 1)"
        case .liveLatencyChanged(let seconds):
            String(format: "Live latency %.1fs", seconds)
        case .liveCatchUpChanged(let active):
            active ? "Live catch-up active" : "Live catch-up complete"
        case .audioSession:
            "Audio session event"
        case .applicationLifecycle:
            "Application lifecycle event"
        case .interstitialStarted:
            "Interstitial started"
        case .interstitialEnded:
            "Interstitial ended"
        case .interstitialSkippable(_, let canSkip):
            canSkip ? "Interstitial can be skipped" : "Interstitial skip locked"
        case .editorialMarkerChanged(let id):
            id == nil ? "Editorial segment ended" : "Editorial segment changed"
        case .upNextPresented:
            "Up Next presented"
        case .upNextAccepted:
            "Up Next accepted"
        case .upNextDismissed:
            "Up Next dismissed"
        case .performanceBudgetExceeded:
            "Performance budget exceeded"
        case .persistableContentKeyStored:
            "Persistable FairPlay key stored"
        case .diagnostic:
            "AVFoundation diagnostic received"
        }
    }

    private static func episode(id: String, url: URL, title: String) -> MediaSource {
        MediaSource(
            id: id,
            url: url,
            fallbackURLs: [
                DemoMedia.bipbopBasic,
                DemoMedia.bipbop16x9,
            ],
            title: title,
            subtitle: "Production playback lab",
            interstitials: id == "adv"
                ? [
                    InterstitialDescriptor(
                        id: "ios-demo-midroll",
                        time: 12,
                        assetURLs: [DemoMedia.bipbop4x3],
                        playoutLimit: 6,
                        skipAfter: 3
                    ),
                ]
                : [],
            editorialMarkers: [
                EditorialMarker(
                    id: "\(id)-intro",
                    kind: .intro,
                    title: "Intro",
                    start: 2,
                    end: 6
                ),
                EditorialMarker(
                    id: "\(id)-chapter",
                    kind: .chapter,
                    title: "Main chapter",
                    start: 6,
                    end: 24
                ),
                EditorialMarker(
                    id: "\(id)-credits",
                    kind: .credits,
                    title: "Credits",
                    start: 24,
                    end: 30
                ),
            ]
        )
    }

    private static func makeSession() -> PlayerSession {
        var configuration = PlayerConfiguration(
            autoplay: true,
            isMuted: false,
            updatesNowPlayingInfo: true,
            preferHardQualityLock: true
        )
        configuration.resumesPlaybackAfterForeground = true
        configuration.liveLatencyPolicy = .lowLatency
        configuration.performanceBudget = PlaybackPerformanceBudget(
            maximumTTFFMilliseconds: 8_000,
            maximumRebufferCount: 3,
            maximumTotalRebufferMilliseconds: 8_000
        )
        let session = PlayerSession(configuration: configuration)
        session.credentialProvider = DemoCredentialProvider()
        return session
    }
}
