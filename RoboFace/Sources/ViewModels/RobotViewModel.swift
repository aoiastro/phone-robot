import Foundation
import SwiftUI

@MainActor
final class RobotViewModel: NSObject, ObservableObject {
    @Published var showSettings = false
    @Published var statusText = "準備中..."
    @Published var heardText = ""
    @Published var pendingPrompt = ""
    @Published var replyText = ""
    @Published var errorText = ""
    @Published var isListening = false
    @Published var isThinking = false
    @Published var isSpeaking = false
    @Published var isDownloading = false
    @Published var downloadProgress: Double = 0
    @Published var audioLevel: Double = 0
    @Published var mouthOpen: Double = 0.12
    @Published var settings = AssistantSettings.load()

    private let modelService = LocalModelService()
    private let synthesizerService = SpeechSynthesizerService()
    private lazy var speechRecognizerService = SpeechRecognizerService(localeIdentifier: settings.speechLocaleIdentifier)

    private var hasStarted = false
    private var captureTask: Task<Void, Never>?
    private var latestPromptFragment = ""
    private var lastTranscriptTimestamp = Date.distantPast
    private var isSceneActive = true

    override init() {
        super.init()
        synthesizerService.delegate = self
        speechRecognizerService.delegate = self
    }

    func startIfNeeded() async {
        guard !hasStarted else { return }
        hasStarted = true
        await requestPermissionsAndStart()
    }

    func handleScenePhase(_ scenePhase: ScenePhase) {
        switch scenePhase {
        case .active:
            isSceneActive = true
            restartListeningIfPossible()
        case .inactive, .background:
            isSceneActive = false
            stopListening()
        @unknown default:
            break
        }
    }

    func presentSettings() {
        showSettings = true
        stopListening()
    }

    func apply(settings newSettings: AssistantSettings) {
        settings = newSettings
        settings.save()
        speechRecognizerService.updateLocale(newSettings.speechLocaleIdentifier)
        restartListeningIfPossible()
    }

    func closeSettings() {
        showSettings = false
        restartListeningIfPossible()
    }

    func downloadModel(with draft: AssistantSettings) {
        Task {
            setDownloadState(active: true, progress: 0)
            do {
                try await modelService.warmUp(settings: draft) { [weak self] progress in
                    self?.setDownloadState(active: progress < 1, progress: progress)
                }
                statusText = "モデルを準備できました"
                errorText = ""
            } catch {
                errorText = error.localizedDescription
                statusText = "モデル準備に失敗しました"
                setDownloadState(active: false, progress: 0)
            }
        }
    }

    func resetConversation() {
        heardText = ""
        pendingPrompt = ""
        replyText = ""
        errorText = ""
        statusText = "「\(settings.trimmedWakeWord)」で話しかけてください"
    }

    private func requestPermissionsAndStart() async {
        let permission = await SpeechRecognizerService.requestPermissions()
        guard permission.speech else {
            statusText = "音声認識の許可が必要です"
            errorText = "設定アプリから音声認識を許可してください。"
            return
        }
        guard permission.microphone else {
            statusText = "マイクの許可が必要です"
            errorText = "設定アプリからマイクを許可してください。"
            return
        }
        errorText = ""
        restartListeningIfPossible()
    }

    private func restartListeningIfPossible() {
        guard isSceneActive, !showSettings, !isThinking, !isSpeaking else { return }
        do {
            try speechRecognizerService.start()
            isListening = true
            statusText = "「\(settings.trimmedWakeWord)」で話しかけてください"
        } catch {
            isListening = false
            errorText = error.localizedDescription
            statusText = "待機を開始できません"
        }
    }

    private func stopListening() {
        captureTask?.cancel()
        captureTask = nil
        latestPromptFragment = ""
        isListening = false
        audioLevel = 0
        mouthOpen = 0.12
        speechRecognizerService.stop()
    }

    private func armPromptCapture(with prompt: String) {
        latestPromptFragment = prompt
        pendingPrompt = prompt
        lastTranscriptTimestamp = Date()
        statusText = prompt.isEmpty ? "続きを聞いています..." : "質問を聞いています..."

        captureTask?.cancel()
        captureTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(250))
                await self.flushPromptIfSilent()
            }
        }
    }

    private func flushPromptIfSilent() async {
        guard !latestPromptFragment.isEmpty else { return }
        guard Date().timeIntervalSince(lastTranscriptTimestamp) > 1.0 else { return }

        let prompt = latestPromptFragment
        latestPromptFragment = ""
        captureTask?.cancel()
        captureTask = nil
        pendingPrompt = prompt
        await submitPrompt(prompt)
    }

    private func submitPrompt(_ prompt: String) async {
        guard !prompt.isEmpty else { return }

        stopListening()
        isThinking = true
        errorText = ""
        statusText = "考えています..."
        replyText = ""

        do {
            let response = try await modelService.respond(to: prompt, settings: settings) { [weak self] progress in
                self?.setDownloadState(active: progress < 1, progress: progress)
            }
            isThinking = false
            replyText = response
            statusText = "話しています..."
            synthesizerService.speak(
                text: response,
                preferredVoiceIdentifier: settings.voiceIdentifier,
                localeIdentifier: settings.speechLocaleIdentifier
            )
        } catch {
            isThinking = false
            errorText = error.localizedDescription
            statusText = "応答に失敗しました"
            restartListeningIfPossible()
        }
    }

    private func extractPrompt(from transcript: String) -> String? {
        let variants = candidateWakeWords()
        let match = variants
            .compactMap { variant in
                transcript.range(of: variant, options: [.caseInsensitive, .backwards])
            }
            .max { lhs, rhs in lhs.lowerBound < rhs.lowerBound }

        guard let match else { return nil }
        return String(transcript[match.upperBound...])
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func candidateWakeWords() -> [String] {
        let base = settings.trimmedWakeWord
        let defaults = ["ロボ", "ろぼ", "ロボット", "ろぼっと"]
        return Array(Set([base, base.lowercased()] + defaults)).sorted { $0.count > $1.count }
    }

    private func setDownloadState(active: Bool, progress: Double) {
        isDownloading = active
        downloadProgress = progress
    }
}

extension RobotViewModel: SpeechRecognizerServiceDelegate {
    func speechRecognizerService(_ service: SpeechRecognizerService, didUpdateTranscript transcript: String) {
        heardText = transcript
        lastTranscriptTimestamp = Date()

        guard let prompt = extractPrompt(from: transcript) else {
            if isListening {
                statusText = "「\(settings.trimmedWakeWord)」で話しかけてください"
            }
            return
        }

        armPromptCapture(with: prompt)
    }

    func speechRecognizerService(_ service: SpeechRecognizerService, didMeasureAudioLevel level: Double) {
        audioLevel = (audioLevel * 0.55) + (level * 0.45)
        guard !isSpeaking else { return }
        mouthOpen = max(0.12, min(0.52, 0.12 + audioLevel * 0.45))
    }

    func speechRecognizerService(_ service: SpeechRecognizerService, didFailWith error: Error) {
        errorText = error.localizedDescription
        statusText = "音声認識を再起動しています..."
    }
}

extension RobotViewModel: SpeechSynthesizerServiceDelegate {
    func speechSynthesizerDidStartSpeaking() {
        isSpeaking = true
        statusText = "話しています..."
    }

    func speechSynthesizerDidFinishSpeaking() {
        isSpeaking = false
        mouthOpen = 0.12
        statusText = "「\(settings.trimmedWakeWord)」で話しかけてください"
        restartListeningIfPossible()
    }

    func speechSynthesizerDidAdvance(to range: NSRange) {
        guard isSpeaking else { return }
        withAnimation(.easeOut(duration: 0.08)) {
            mouthOpen = 0.86
        }
        Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(110))
            await self?.closeMouthIfStillSpeaking()
        }
    }

    private func closeMouthIfStillSpeaking() {
        guard isSpeaking else { return }
        withAnimation(.easeIn(duration: 0.09)) {
            mouthOpen = 0.22
        }
    }
}
