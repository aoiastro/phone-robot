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

- 基本:
  `lmstudio-community/Qwen2.5-1.5B-Instruct-GGUF` のように `開発者/モデル名` を入力
- 任意:
  `.gguf` ファイル名も入力可能

ファイル名が空の場合は Hugging Face API から `.gguf` 候補を自動選択します。

## 実装メモ

- 音声認識は `Speech` フレームワークのオンデバイス認識を要求しています
- 日本語のオンデバイス音声認識が未導入の端末では、音声機能が使えないことがあります
- AltStore で再署名しやすいよう、Actions では未署名 `ipa` を作ります
- `LocalLLMClient` は 2026-03-27 時点でタグ `0.4.6` 固定だと `mlx-swift-lm` の不安定版依存で解決失敗しやすいため、`project.yml` では `main` ブランチ参照にしています
- 2026-03-27 時点では Xcode 16.4 の iOS ビルドで `LocalLLMClientMLX` を含めると `mlx-swift-lm` 依存グラフで失敗しやすいため、このアプリは `LocalLLMClientLlama` ベースに寄せています
- 大きいモデルは iPhone のメモリ制限にかかりやすいので、最初は 1B〜3B 前後のモデル推奨です

## GitHub Actions

`[Actions] -> [Build Unsigned IPA]` を実行すると `RoboFace-unsigned.ipa` がアーティファクトに出ます。

## ローカルで開く

1. `brew install xcodegen`
2. `xcodegen generate`
3. `open RoboFace.xcodeproj`

## 参考

- `tattn/LocalLLMClient`: https://github.com/tattn/LocalLLMClient
