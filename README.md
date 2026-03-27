# RoboFace

`LocalLLMClient` を使って、iPhone 単体でローカル LLM を動かすロボット風アプリです。通常時は横向き全画面で顔を表示し、音声で「ロボ」と話しかけると、その後の発話をローカル LLM に送り、返答を TTS で読み上げます。

## できること

- 横向き固定 + 全画面のロボット顔 UI
- 画面ダブルタップで設定シートを表示
- オンデバイス音声認識でウェイクワード検出
- `LocalLLMClient` で Hugging Face からモデルをダウンロード
- LLM の返答を `AVSpeechSynthesizer` で読み上げ
- 読み上げに合わせた口パク
- GitHub Actions で署名なし `ipa` を生成

## モデル指定

- MLX の場合:
  `mlx-community/Qwen3-1.7B-4bit` のように `開発者/モデル名` を入力
- GGUF の場合:
  リポジトリ ID に加えて `.gguf` ファイル名も入力

設定画面の `自動` モードでは、ファイル名が空なら MLX、ファイル名がある場合は GGUF として扱います。

## 実装メモ

- 音声認識は `Speech` フレームワークのオンデバイス認識を要求しています
- 日本語のオンデバイス音声認識が未導入の端末では、音声機能が使えないことがあります
- AltStore で再署名しやすいよう、Actions では未署名 `ipa` を作ります
- 大きいモデルは iPhone のメモリ制限にかかりやすいので、最初は 1B〜3B 前後のモデル推奨です

## GitHub Actions

`[Actions] -> [Build Unsigned IPA]` を実行すると `RoboFace-unsigned.ipa` がアーティファクトに出ます。

## ローカルで開く

1. `brew install xcodegen`
2. `xcodegen generate`
3. `open RoboFace.xcodeproj`

## 参考

- `tattn/LocalLLMClient`: https://github.com/tattn/LocalLLMClient
