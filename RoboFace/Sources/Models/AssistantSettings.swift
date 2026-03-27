import Foundation

enum ModelBackend: String, CaseIterable, Codable, Identifiable {
    case auto
    case mlx
    case llama

    var id: String { rawValue }

    var title: String {
        switch self {
        case .auto:
            return "自動"
        case .mlx:
            return "MLX"
        case .llama:
            return "GGUF"
        }
    }

    var helperText: String {
        switch self {
        case .auto:
            return "ファイル名が空なら MLX、ファイル名ありなら GGUF として扱います。"
        case .mlx:
            return "Hugging Face の `開発者/モデル名` をそのまま指定します。"
        case .llama:
            return "GGUF はリポジトリ ID に加えて `.gguf` ファイル名が必要です。"
        }
    }
}

struct AssistantSettings: Codable, Equatable {
    static let storageKey = "robo_face.settings"

    var backend: ModelBackend = .auto
    var modelRepositoryID: String = "mlx-community/Qwen3-1.7B-4bit"
    var modelFilename: String = ""
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

