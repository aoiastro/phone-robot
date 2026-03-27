import AVFoundation
import Foundation

protocol SpeechSynthesizerServiceDelegate: AnyObject {
    @MainActor
    func speechSynthesizerDidStartSpeaking()
    @MainActor
    func speechSynthesizerDidFinishSpeaking()
    @MainActor
    func speechSynthesizerDidAdvance(to range: NSRange)
}

@MainActor
final class SpeechSynthesizerService: NSObject, AVSpeechSynthesizerDelegate {
    weak var delegate: SpeechSynthesizerServiceDelegate?

    private let synthesizer = AVSpeechSynthesizer()
    private let audioSession = AVAudioSession.sharedInstance()

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func speak(text: String, preferredVoiceIdentifier: String, localeIdentifier: String) {
        stop()
        try? audioSession.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try? audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = 0.48
        utterance.pitchMultiplier = 0.95
        utterance.preUtteranceDelay = 0.02
        utterance.postUtteranceDelay = 0.08
        utterance.voice = resolveVoice(preferredVoiceIdentifier: preferredVoiceIdentifier, localeIdentifier: localeIdentifier)

        synthesizer.speak(utterance)
    }

    func stop() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        try? audioSession.setActive(false, options: .notifyOthersOnDeactivation)
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        Task { @MainActor [weak self] in
            self?.notifyDidStartSpeaking()
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor [weak self] in
            self?.notifyDidFinishSpeaking()
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor [weak self] in
            self?.notifyDidFinishSpeaking()
        }
    }

    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        willSpeakRangeOfSpeechString characterRange: NSRange,
        utterance: AVSpeechUtterance
    ) {
        Task { @MainActor [weak self] in
            self?.notifyDidAdvance(to: characterRange)
        }
    }

    private func notifyDidStartSpeaking() {
        delegate?.speechSynthesizerDidStartSpeaking()
    }

    private func notifyDidFinishSpeaking() {
        delegate?.speechSynthesizerDidFinishSpeaking()
        try? audioSession.setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func notifyDidAdvance(to characterRange: NSRange) {
        delegate?.speechSynthesizerDidAdvance(to: characterRange)
    }

    static func voiceOptions(for localeIdentifier: String) -> [VoiceOption] {
        let trimmedLocale = localeIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
        let prefix = trimmedLocale.split(separator: "-").first.map(String.init) ?? trimmedLocale

        let voices = AVSpeechSynthesisVoice.speechVoices()
            .filter { voice in
                guard !trimmedLocale.isEmpty else { return true }
                return voice.language.hasPrefix(trimmedLocale) || voice.language.hasPrefix(prefix)
            }
            .sorted { lhs, rhs in
                if lhs.language == rhs.language {
                    return lhs.name < rhs.name
                }
                return lhs.language < rhs.language
            }
            .map { voice in
                VoiceOption(
                    id: voice.identifier,
                    name: voice.name,
                    language: voice.language
                )
            }

        return [.systemDefault] + voices
    }

    private func resolveVoice(preferredVoiceIdentifier: String, localeIdentifier: String) -> AVSpeechSynthesisVoice? {
        if !preferredVoiceIdentifier.isEmpty,
           let voice = AVSpeechSynthesisVoice(identifier: preferredVoiceIdentifier) {
            return voice
        }
        return AVSpeechSynthesisVoice(language: localeIdentifier)
    }
}
