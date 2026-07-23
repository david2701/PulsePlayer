import Foundation

@MainActor
extension PlayerSession {
    func sourceWithFreshCredentials(
        _ source: MediaSource,
        reason: PlaybackCredentialRefreshReason
    ) async throws -> (MediaSource, PlaybackCredentials?) {
        guard let credentialProvider else { return (source, nil) }
        metrics.credentialRefreshCount += 1
        emitProduction(.credentialRefreshStarted(reason: reason))
        do {
            let credentials = try await credentialProvider.credentials(
                for: source,
                reason: reason
            )
            emitProduction(.credentialRefreshSucceeded(reason: reason))
            return (source.replacingCredentials(credentials), credentials)
        } catch {
            let message = URLSanitizer.sanitizeMessage(error.localizedDescription)
            emitProduction(.credentialRefreshFailed(reason: reason, message: message))
            throw error
        }
    }

    func scheduleCredentialRefresh(
        credentials: PlaybackCredentials?,
        source: MediaSource
    ) {
        credentialRefreshTask?.cancel()
        credentialRefreshTask = nil
        credentialGeneration &+= 1
        guard let delay = credentials?.refreshAfter, credentialProvider != nil else { return }

        let generation = credentialGeneration
        credentialRefreshTask = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                try await self.dependencies.clock.sleep(for: max(.zero, delay))
            } catch {
                return
            }
            guard generation == self.credentialGeneration,
                  self.currentSource?.id == source.id,
                  self.status != .invalidated
            else { return }
            await self.refreshCredentialsProactively()
        }
    }

    public func refreshPlaybackCredentials() async {
        await refreshCredentials(reason: .manual)
    }

    private func refreshCredentialsProactively() async {
        await refreshCredentials(reason: .expiring)
    }

    private func refreshCredentials(reason: PlaybackCredentialRefreshReason) async {
        guard let source = currentSource, credentialProvider != nil else { return }
        do {
            let (updated, credentials) = try await sourceWithFreshCredentials(
                source,
                reason: reason
            )
            try Task.checkCancellation()
            try await reloadPreservingPlayback(with: updated)
            scheduleCredentialRefresh(credentials: credentials, source: updated)
        } catch is CancellationError {
            return
        } catch {
            // Proactive/manual refresh never tears down a stream that is still playing.
            if !isPlaying && status != .ready {
                let ns = error as NSError
                fail(with: .assetLoadFailed(
                    underlying: URLSanitizer.sanitizeMessage(ns.localizedDescription),
                    recoverable: true
                ))
            }
        }
    }

    func reloadPreservingPlayback(with source: MediaSource) async throws {
        let resumeTime = engine.currentTime()
        let selectedAudio = engine.audioTracks().first(where: \.isSelected)?.id
        let selectedText = engine.textTracks().first(where: \.isSelected)?.id
        let shouldResume = wantsPlaying

        loadTask?.cancel()
        loadTask = nil
        startupTask?.cancel()
        startupTask = nil
        stallTask?.cancel()
        stallTask = nil
        autoRetryTask?.cancel()
        autoRetryTask = nil
        loadGeneration &+= 1
        let generation = loadGeneration

        currentSource = source
        pendingStartAt = resumeTime
        wantsPlaying = shouldResume
        currentError = nil
        _ = apply(.load, isLive: source.isLive)
        startStartupWatchdog(generation: generation)

        try await engine.replaceCurrentItem(with: source)
        guard generation == loadGeneration, !Task.isCancelled else {
            throw CancellationError()
        }
        await refreshQualities(for: source)
        if let selectedAudio {
            engine.selectAudioTrack(id: selectedAudio)
        }
        if let selectedText {
            engine.selectTextTrack(id: selectedText)
        }
    }
}
