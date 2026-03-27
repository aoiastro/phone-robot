import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: RobotViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var draft: AssistantSettings
    @State private var voiceOptions: [VoiceOption]

    init(viewModel: RobotViewModel) {
        self.viewModel = viewModel
        let current = viewModel.settings
        _draft = State(initialValue: current)
        _voiceOptions = State(initialValue: SpeechSynthesizerService.voiceOptions(for: current.speechLocaleIdentifier))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Group {
                        sectionTitle("モデル")
                        Picker("バックエンド", selection: $draft.backend) {
                            ForEach(ModelBackend.allCases) { backend in
                                Text(backend.title).tag(backend)
                            }
                        }
                        .pickerStyle(.segmented)

                        Text(draft.backend.helperText)
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        TextField("Hugging Face リポジトリ ID", text: $draft.modelRepositoryID)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .textFieldStyle(.roundedBorder)

                        TextField("GGUF ファイル名（任意）", text: $draft.modelFilename)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .textFieldStyle(.roundedBorder)

                        Button {
                            viewModel.downloadModel(with: draft)
                        } label: {
                            Label("モデルをダウンロード / 準備", systemImage: "arrow.down.circle")
                        }
                        .buttonStyle(.borderedProminent)

                        if viewModel.isDownloading {
                            ProgressView(value: viewModel.downloadProgress)
                        }
                    }

                    Group {
                        sectionTitle("音声")

                        TextField("ウェイクワード", text: $draft.wakeWord)
                            .textFieldStyle(.roundedBorder)

                        TextField("音声認識ロケール", text: $draft.speechLocaleIdentifier)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .textFieldStyle(.roundedBorder)
                            .onChange(of: draft.speechLocaleIdentifier) { _, newValue in
                                voiceOptions = SpeechSynthesizerService.voiceOptions(for: newValue)
                                if !voiceOptions.contains(where: { $0.id == draft.voiceIdentifier }) {
                                    draft.voiceIdentifier = ""
                                }
                            }

                        Picker("読み上げ音声", selection: $draft.voiceIdentifier) {
                            ForEach(voiceOptions) { voice in
                                Text(voice.id.isEmpty ? voice.name : "\(voice.name) (\(voice.language))")
                                    .tag(voice.id)
                            }
                        }
                        .pickerStyle(.menu)
                    }

                    Group {
                        sectionTitle("システムプロンプト")

                        TextEditor(text: $draft.systemPrompt)
                            .frame(minHeight: 180)
                            .padding(10)
                            .background(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(Color(uiColor: .secondarySystemBackground))
                            )
                    }

                    Group {
                        sectionTitle("メモ")

                        Text("MLX を使うと `開発者/モデル名` だけで扱いやすいです。GGUF は `.gguf` のファイル名が必要です。")
                        Text("音声認識はオンデバイス限定にしているので、端末に対象言語の音声データがない場合は設定とダウンロードが必要です。")
                        Text("大きいモデルはメモリ制限に引っかかりやすいので、まずは 1B〜3B クラス推奨です。")
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
                .padding(24)
            }
            .navigationTitle("ロボ設定")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("会話をクリア") {
                        viewModel.resetConversation()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("保存して閉じる") {
                        viewModel.apply(settings: draft)
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .fontWeight(.bold)
    }
}
