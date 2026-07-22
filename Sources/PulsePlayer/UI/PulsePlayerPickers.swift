import SwiftUI

struct TrackPickerSheet: View {
    let session: PlayerSession
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Audio") {
                    ForEach(session.availableAudioTracks) { track in
                        Button {
                            session.selectAudioTrack(id: track.id)
                            dismiss()
                        } label: {
                            HStack {
                                Text(track.displayName)
                                Spacer()
                                if track.isSelected {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                }
                Section("Text / Subtitles") {
                    Button {
                        session.selectTextTrack(id: nil)
                        dismiss()
                    } label: {
                        Text("Off")
                    }
                    ForEach(session.availableTextTracks) { track in
                        Button {
                            session.selectTextTrack(id: track.id)
                            dismiss()
                        } label: {
                            HStack {
                                Text(track.displayName)
                                if track.isExternal {
                                    Text("EXT").font(.caption2).opacity(0.5)
                                }
                                Spacer()
                                if track.isSelected {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Tracks")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct QualityPickerSheet: View {
    let session: PlayerSession
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Button {
                    Task {
                        await session.setQualityAuto()
                        dismiss()
                    }
                } label: {
                    HStack {
                        Text("Auto")
                        Spacer()
                        if session.selectedQualityId == StreamQuality.auto.id {
                            Image(systemName: "checkmark")
                        }
                    }
                }
                ForEach(session.availableQualities) { q in
                    Button {
                        Task {
                            await session.setQuality(q)
                            dismiss()
                        }
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(q.label)
                                Text(q.supportsHardLock ? "Hard lock" : "Soft cap")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Text("· \(q.bandwidth / 1000) kbps")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            if session.selectedQualityId == q.id {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }
            .navigationTitle(session.isQualityHardLocked ? "Quality (locked)" : "Quality")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
