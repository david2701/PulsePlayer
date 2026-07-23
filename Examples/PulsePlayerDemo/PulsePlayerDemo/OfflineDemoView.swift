import PulsePlayer
import SwiftUI

struct OfflineDemoView: View {
    @State private var session = PlayerSession(
        configuration: PlayerConfiguration(autoplay: false, isMuted: false)
    )
    @State private var items: [OfflineDownloadItem] = []
    @State private var message = "Resume-or-enqueue · storage quota · full chrome playback"
    @State private var isBusy = false
    @State private var certURL = ""
    @State private var licenseURL = ""
    @State private var encryptedAssetURL = ""
    @State private var contentKeyID = "offline-asset-1"

    private let downloadID = "demo-bipbop"

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                let playerHeight = min(max(geo.size.width * 9 / 16, 240), geo.size.height * 0.40)
                VStack(spacing: 0) {
                    PulsePlayerView(
                        session: session,
                        chrome: .full
                    )
                    .frame(maxWidth: .infinity)
                    .frame(height: playerHeight)
                    .background(Color.black)

                    List {
                        Section("Storage") {
                            LabeledContent("Used") {
                                Text(OfflineDownloadManager.shared.usedStorageDisplay)
                            }
                            if let limit = OfflineDownloadManager.shared.storageLimitDisplay {
                                LabeledContent("Limit") { Text(limit) }
                            }
                            Text(message)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Section("Catalog") {
                            if items.isEmpty {
                                Text("No downloads")
                                    .foregroundStyle(.secondary)
                            } else {
                                ForEach(items) { item in
                                    VStack(alignment: .leading, spacing: 6) {
                                        HStack {
                                            Text(item.title ?? item.id)
                                                .font(.subheadline.weight(.semibold))
                                            Spacer()
                                            Text(item.state.rawValue)
                                                .font(.caption.monospaced())
                                                .foregroundStyle(color(for: item.state))
                                        }
                                        if item.state == .downloading || item.state == .queued {
                                            ProgressView(value: item.progress)
                                        }
                                        if let err = item.errorMessage {
                                            Text(err)
                                                .font(.caption2)
                                                .foregroundStyle(.red)
                                        }
                                        HStack {
                                            if item.isPlayableOffline {
                                                Button("Play") {
                                                    Task { await play(id: item.id) }
                                                }
                                            }
                                            if item.state == .failed || item.state == .cancelled {
                                                Button("Retry") {
                                                    retry(id: item.id)
                                                }
                                            }
                                            Button("Remove", role: .destructive) {
                                                remove(id: item.id)
                                            }
                                        }
                                        .buttonStyle(.bordered)
                                        .font(.caption)
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                        }

                        Section("Protected offline (FairPlay)") {
                            Text(
                                "Uses a real FPS certificate, CKC server and persistable key store. Public test credentials do not exist."
                            )
                            .font(.caption)
                            .foregroundStyle(.secondary)

                            TextField("Certificate URL", text: $certURL)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                            TextField("License URL", text: $licenseURL)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                            TextField("Encrypted HLS URL", text: $encryptedAssetURL)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                            TextField("Content key asset id", text: $contentKeyID)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()

                            Button {
                                enqueueProtected()
                            } label: {
                                Label(
                                    "Download protected asset",
                                    systemImage: "lock.circle"
                                )
                            }
                            .disabled(isBusy)
                        }

                        Section {
                            Button {
                                Task { await enqueue() }
                            } label: {
                                Label(
                                    isBusy ? "Working…" : "Download / resume BipBop",
                                    systemImage: "arrow.down.circle.fill"
                                )
                            }
                            .disabled(isBusy)

                            Button("Enforce storage limit") {
                                do {
                                    try OfflineDownloadManager.shared.enforceStorageLimit()
                                    refresh()
                                    message = "Storage enforced · \(OfflineDownloadManager.shared.usedStorageDisplay)"
                                } catch {
                                    message = error.localizedDescription
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Offline")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                refresh()
                OfflineDownloadManager.shared.onChange = { items = $0 }
            }
            .onDisappear { session.pause() }
        }
    }

    private func color(for state: OfflineDownloadState) -> Color {
        switch state {
        case .completed: return .green
        case .downloading, .queued: return .cyan
        case .failed: return .red
        case .cancelled: return .orange
        }
    }

    private func refresh() {
        items = OfflineDownloadManager.shared.items
    }

    private func enqueue() async {
        isBusy = true
        defer { isBusy = false }
        do {
            let item = try OfflineDownloadManager.shared.resumeOrEnqueue(
                sourceURL: DemoMedia.bipbopHLS,
                id: downloadID,
                title: "BipBop offline"
            )
            message = "State: \(item.state.rawValue)"
            refresh()
        } catch {
            message = error.localizedDescription
        }
    }

    private func enqueueProtected() {
        guard let certificate = URL(string: certURL),
              let license = URL(string: licenseURL),
              let asset = URL(string: encryptedAssetURL),
              !contentKeyID.isEmpty
        else {
            message = "Fill certificate, license, encrypted HLS and content key id"
            return
        }

        isBusy = true
        defer { isBusy = false }
        do {
            let provider = HTTPContentKeyProvider(
                configuration: .init(
                    certificateURL: certificate,
                    licenseURL: license,
                    licenseBody: .jsonBase64SPC
                )
            )
            let keyStore = try PersistableContentKeyFileStore()
            session.contentKeyProvider = provider
            session.persistableContentKeyStore = keyStore
            OfflineDownloadManager.shared.contentKeyProvider = provider
            OfflineDownloadManager.shared.persistableContentKeyStore = keyStore

            let item = try OfflineDownloadManager.shared.enqueue(
                sourceURL: asset,
                id: "fairplay-\(contentKeyID)",
                title: "Protected FairPlay asset",
                contentKeyAssetId: contentKeyID
            )
            message = "Protected download: \(item.state.rawValue)"
            refresh()
        } catch {
            message = error.localizedDescription
        }
    }

    private func play(id: String) async {
        guard let source = OfflineDownloadManager.shared.playableSource(id: id) else {
            message = "Not playable yet"
            return
        }
        await session.load(source)
        session.play()
        message = "Playing offline asset"
    }

    private func retry(id: String) {
        do {
            _ = try OfflineDownloadManager.shared.retry(id: id)
            message = "Retry started"
            refresh()
        } catch {
            message = error.localizedDescription
        }
    }

    private func remove(id: String) {
        do {
            try OfflineDownloadManager.shared.remove(id: id)
            message = "Removed"
            refresh()
        } catch {
            message = error.localizedDescription
        }
    }
}
