import SwiftUI

struct TrackPickerSheet: View {
    let session: PlayerSession
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section(PulsePlayerLocalization.string("Audio")) {
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
                                        .accessibilityHidden(true)
                                }
                            }
                        }
                        .accessibilityAddTraits(
                            track.isSelected ? .isSelected : []
                        )
                    }
                }
                Section(PulsePlayerLocalization.string("Text / Subtitles")) {
                    Button {
                        session.selectTextTrack(id: nil)
                        dismiss()
                    } label: {
                        Text(PulsePlayerLocalization.string("Off"))
                    }
                    .accessibilityAddTraits(
                        session.availableTextTracks.allSatisfy { !$0.isSelected }
                            ? .isSelected
                            : []
                    )
                    ForEach(session.availableTextTracks) { track in
                        Button {
                            session.selectTextTrack(id: track.id)
                            dismiss()
                        } label: {
                            HStack {
                                Text(track.displayName)
                                if track.isExternal {
                                    Text(PulsePlayerLocalization.string("External"))
                                        .font(.caption2)
                                        .opacity(0.6)
                                }
                                Spacer()
                                if track.isSelected {
                                    Image(systemName: "checkmark")
                                        .accessibilityHidden(true)
                                }
                            }
                        }
                        .accessibilityAddTraits(
                            track.isSelected ? .isSelected : []
                        )
                    }
                }
            }
            .navigationTitle(PulsePlayerLocalization.string("Tracks"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(PulsePlayerLocalization.string("Done")) { dismiss() }
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
                        Text(PulsePlayerLocalization.string("Auto"))
                        Spacer()
                        if session.selectedQualityId == StreamQuality.auto.id {
                            Image(systemName: "checkmark")
                                .accessibilityHidden(true)
                        }
                    }
                }
                .accessibilityAddTraits(
                    session.selectedQualityId == StreamQuality.auto.id
                        ? .isSelected
                        : []
                )
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
                                Text(
                                    session.configuration.preferHardQualityLock
                                        && q.supportsHardLock
                                        ? PulsePlayerLocalization.string("Hard lock")
                                        : PulsePlayerLocalization.string("Soft cap")
                                )
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Text("· \(q.bandwidth / 1000) kbps")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            if session.selectedQualityId == q.id {
                                Image(systemName: "checkmark")
                                    .accessibilityHidden(true)
                            }
                        }
                    }
                    .accessibilityAddTraits(
                        session.selectedQualityId == q.id ? .isSelected : []
                    )
                }
            }
            .navigationTitle(
                session.isQualityHardLocked
                    ? PulsePlayerLocalization.string("Quality (locked)")
                    : PulsePlayerLocalization.string("Quality")
            )
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(PulsePlayerLocalization.string("Done")) { dismiss() }
                }
            }
        }
    }
}
