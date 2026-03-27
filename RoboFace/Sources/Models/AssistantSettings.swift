import Foundation

enum ModelBackend: String, CaseIterable, Codable, Identifiable {
    case auto
    case llama

    var id: String { rawValue }

    var title: String {
        switch self {
        case .auto:
            return "自動"
        case .llama:
            return "GGUF"
        }
    }

    var helperText: String {
        switch self {
        case .auto:
            return "通常はこれで大丈夫です。.gguf ファイル名が空なら自動で候補を探します。"
        case .llama:
            return "必要なら `.gguf` ファイル名を明示できます。空欄なら候補を自動選択します。"
        }
    }
}

struct AssistantSettings: Codable, Equatable {
    static let storageKey = "robo_face.settings"

    var backend: ModelBackend = .auto
    var modelRepositoryID: String = "lmstudio-community/Qwen2.5-1.5B-Instruct-GGUF"
    var modelFilename: String = "qwen2.5-1.5b-instruct-q4_k_m.gguf"
    var wakeWord: String = "ロボ"
    var speechLocaleIdentifier: String = "ja-JP"
    var voiceIdentifier: String = ""
    var systemPrompt: String = """
    あなたは横向き画面いっぱいに表示される、やさしく少しロボットっぽい相棒です。
    日本語で短く分かりやすく答えてください。
    音声で読み上げるので、箇条書きや記号は控えめにしてください。
    """

    var trimmedRepositoryID: String {
        modelRepositoryID.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedFilename: String {
        modelFilename.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedWakeWord: String {
        wakeWord.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "ロボ" : wakeWord.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func load(from defaults: UserDefaults = .standard) -> AssistantSettings {
        guard
            let data = defaults.data(forKey: storageKey),
            let settings = try? JSONDecoder().decode(AssistantSettings.self, from: data)
        else {
            return AssistantSettings()
        }
        return settings
    }

    func save(to defaults: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(self) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }
}

struct VoiceOption: Identifiable, Hashable {
    let id: String
    let name: String
    let language: String

    static let systemDefault = VoiceOption(
        id: "",
        name: "システム既定",
        language: "default"
    )
}
