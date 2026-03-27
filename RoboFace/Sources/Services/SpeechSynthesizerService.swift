import AVFoundation
import Foundation

protocol SpeechSynthesizerServiceDelegate: AnyObject {
    func speechSynthesizerDidStartSpeaking(_ service: SpeechSynthesizerService)
    func speechSynthesizerDidFinishSpeaking(_ service: SpeechSynthesizerService)
    func speechSynthesizerService(_ service: SpeechSynthesizerService, didAdvanceTo range: NSRange)
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

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        delegate?.speechSynthesizerDidStartSpeaking(self)
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        delegate?.speechSynthesizerDidFinishSpeaking(self)
        try? audioSession.setActive(false, options: .notifyOthersOnDeactivation)
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        delegate?.speechSynthesizerDidFinishSpeaking(self)
        try? audioSession.setActive(false, options: .notifyOthersOnDeactivation)
    }

    func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        willSpeakRangeOfSpeechString characterRange: NSRange,
        utterance: AVSpeechUtterance
    ) {
        delegate?.speechSynthesizerService(self, didAdvanceTo: characterRange)
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

