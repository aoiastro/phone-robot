import AVFoundation
import Foundation
import Speech

protocol SpeechRecognizerServiceDelegate: AnyObject {
    @MainActor
    func speechRecognizerService(_ service: SpeechRecognizerService, didUpdateTranscript transcript: String)
    @MainActor
    func speechRecognizerService(_ service: SpeechRecognizerService, didMeasureAudioLevel level: Double)
    @MainActor
    func speechRecognizerService(_ service: SpeechRecognizerService, didFailWith error: Error)
}

enum SpeechRecognizerServiceError: LocalizedError {
    case speechPermissionDenied
    case microphonePermissionDenied
    case recognizerUnavailable
    case onDeviceRecognitionUnavailable
    case failedToStartEngine

    var errorDescription: String? {
        switch self {
        case .speechPermissionDenied:
            return "音声認識の許可がありません。"
        case .microphonePermissionDenied:
            return "マイクの許可がありません。"
        case .recognizerUnavailable:
            return "この言語の音声認識が利用できません。"
        case .onDeviceRecognitionUnavailable:
            return "この端末では選択中の言語のオンデバイス音声認識が利用できません。"
        case .failedToStartEngine:
            return "音声認識エンジンを開始できませんでした。"
        }
    }
}

@MainActor
final class SpeechRecognizerService: NSObject {
    weak var delegate: SpeechRecognizerServiceDelegate?

    private let audioEngine = AVAudioEngine()
    private let audioSession = AVAudioSession.sharedInstance()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var speechRecognizer: SFSpeechRecognizer?
    private var localeIdentifier: String
    private(set) var isRunning = false

    init(localeIdentifier: String = "ja-JP") {
        self.localeIdentifier = localeIdentifier
        self.speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: localeIdentifier))
        super.init()
    }

    func updateLocale(_ identifier: String) {
        let newIdentifier = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !newIdentifier.isEmpty, newIdentifier != localeIdentifier else { return }
        let wasRunning = isRunning
        stop()
        localeIdentifier = newIdentifier
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: newIdentifier))
        if wasRunning {
            try? start()
        }
    }

    func start() throws {
        if isRunning {
            return
        }
        guard SFSpeechRecognizer.authorizationStatus() == .authorized else {
            throw SpeechRecognizerServiceError.speechPermissionDenied
        }
        guard AVAudioApplication.shared.recordPermission == .granted else {
            throw SpeechRecognizerServiceError.microphonePermissionDenied
        }
        guard let speechRecognizer else {
            throw SpeechRecognizerServiceError.recognizerUnavailable
        }
        guard speechRecognizer.isAvailable else {
            throw SpeechRecognizerServiceError.recognizerUnavailable
        }
        guard speechRecognizer.supportsOnDeviceRecognition else {
            throw SpeechRecognizerServiceError.onDeviceRecognitionUnavailable
        }

        if audioEngine.isRunning {
            stop()
        }

        try configureAudioSession()
        installTapIfNeeded()
        beginRecognitionTask(using: speechRecognizer)

        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            stop()
            throw SpeechRecognizerServiceError.failedToStartEngine
        }

        isRunning = true
    }

    func stop() {
        isRunning = false
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest?.endAudio()
        recognitionRequest = nil

        if audioEngine.inputNode.numberOfInputs > 0 {
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        try? audioSession.setActive(false, options: .notifyOthersOnDeactivation)
    }

    func refreshRecognitionTask() {
        guard isRunning, let speechRecognizer else { return }
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        beginRecognitionTask(using: speechRecognizer)
    }

    private func configureAudioSession() throws {
        try audioSession.setCategory(
            .record,
            mode: .measurement,
            options: [.duckOthers, .allowBluetooth]
        )
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
    }

    private func installTapIfNeeded() {
        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1_024, format: format) { [weak self] buffer, _ in
            guard let self else { return }
            self.recognitionRequest?.append(buffer)
            let level = Self.normalizedLevel(from: buffer)
            Task { [weak self] in
                await MainActor.run {
                    guard let self else { return }
                    self.delegate?.speechRecognizerService(self, didMeasureAudioLevel: level)
                }
            }
        }
    }

    private func beginRecognitionTask(using recognizer: SFSpeechRecognizer) {
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = true
        request.taskHint = .dictation
        recognitionRequest = request

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            Task { @MainActor in
                if let result {
                    self.delegate?.speechRecognizerService(self, didUpdateTranscript: result.bestTranscription.formattedString)
                    if result.isFinal, self.isRunning {
                        self.refreshRecognitionTask()
                    }
                }
                if let error {
                    self.delegate?.speechRecognizerService(self, didFailWith: error)
                    if self.isRunning {
                        self.refreshRecognitionTask()
                    }
                }
            }
        }
    }

    static func requestPermissions() async -> (speech: Bool, microphone: Bool) {
        let speechAuthorized = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
        let microphoneAuthorized = await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
        return (speechAuthorized, microphoneAuthorized)
    }

    private static func normalizedLevel(from buffer: AVAudioPCMBuffer) -> Double {
        guard
            let channelData = buffer.floatChannelData?.pointee
        else {
            return 0
        }

        let frameLength = Int(buffer.frameLength)
        guard frameLength > 0 else { return 0 }

        var sum: Float = 0
        for index in 0 ..< frameLength {
            let sample = channelData[index]
            sum += sample * sample
        }

        let rms = sqrt(sum / Float(frameLength))
        let normalized = min(max(Double(rms) * 6.0, 0), 1)
        return normalized
    }
}
