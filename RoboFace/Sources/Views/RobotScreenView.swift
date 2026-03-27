import SwiftUI

struct RobotScreenView: View {
    @ObservedObject var viewModel: RobotViewModel

    var body: some View {
        ZStack {
            background

            VStack(spacing: 24) {
                topBar
                Spacer(minLength: 0)

                RobotFaceView(
                    mouthOpen: viewModel.mouthOpen,
                    audioLevel: viewModel.audioLevel,
                    isListening: viewModel.isListening,
                    isThinking: viewModel.isThinking,
                    isSpeaking: viewModel.isSpeaking
                )
                .frame(maxWidth: 820, maxHeight: 420)

                Spacer(minLength: 0)
                transcriptPanel
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 22)
        }
        .ignoresSafeArea()
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            viewModel.presentSettings()
        }
        .sheet(isPresented: $viewModel.showSettings, onDismiss: {
            viewModel.closeSettings()
        }) {
            SettingsView(viewModel: viewModel)
                .presentationDetents([.large])
        }
    }

    private var background: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.03, green: 0.07, blue: 0.14),
                    Color(red: 0.04, green: 0.16, blue: 0.24),
                    Color(red: 0.09, green: 0.27, blue: 0.31)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(Color(red: 0.0, green: 0.88, blue: 0.86).opacity(0.16))
                .frame(width: 420, height: 420)
                .blur(radius: 18)
                .offset(x: -280, y: -120)

            Circle()
                .fill(Color(red: 1.0, green: 0.62, blue: 0.18).opacity(0.13))
                .frame(width: 360, height: 360)
                .blur(radius: 10)
                .offset(x: 330, y: 120)

            VStack(spacing: 8) {
                ForEach(0..<18, id: \.self) { _ in
                    Rectangle()
                        .fill(.white.opacity(0.03))
                        .frame(height: 1)
                }
            }
            .blur(radius: 0.6)
        }
    }

    private var topBar: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 8) {
                Text("ROBOFACE")
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .tracking(3)
                    .foregroundStyle(.white.opacity(0.96))

                Text(viewModel.statusText)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(statusColor.opacity(0.94))

                if viewModel.isDownloading {
                    ProgressView(value: viewModel.downloadProgress)
                        .tint(Color(red: 0.0, green: 0.9, blue: 0.86))
                        .frame(width: 220)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 8) {
                Text("ダブルタップで設定")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.75))

                Text(viewModel.settings.trimmedRepositoryID)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.52))
                    .lineLimit(1)
            }
        }
    }

    private var transcriptPanel: some View {
        VStack(spacing: 12) {
            InfoBubble(title: "HEARD", text: viewModel.pendingPrompt.isEmpty ? viewModel.heardText : viewModel.pendingPrompt, tint: Color(red: 0.08, green: 0.85, blue: 0.84))
            InfoBubble(title: "ROBO", text: viewModel.replyText, tint: Color(red: 1.0, green: 0.68, blue: 0.28))

            if !viewModel.errorText.isEmpty {
                Text(viewModel.errorText)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Color(red: 1.0, green: 0.78, blue: 0.72))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 6)
            }
        }
    }

    private var statusColor: Color {
        if viewModel.isSpeaking {
            return Color(red: 1.0, green: 0.68, blue: 0.28)
        }
        if viewModel.isThinking {
            return Color(red: 0.98, green: 0.84, blue: 0.22)
        }
        if viewModel.isListening {
            return Color(red: 0.08, green: 0.85, blue: 0.84)
        }
        return .white
    }
}

private struct InfoBubble: View {
    let title: String
    let text: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 11, weight: .black, design: .rounded))
                .tracking(2)
                .foregroundStyle(tint.opacity(0.92))

            Text(text.isEmpty ? "..." : text)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(text.isEmpty ? 0.35 : 0.92))
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.black.opacity(0.2))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(tint.opacity(0.22), lineWidth: 1)
                )
        )
    }
}
