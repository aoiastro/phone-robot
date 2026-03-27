import SwiftUI

struct RobotFaceView: View {
    let mouthOpen: Double
    let audioLevel: Double
    let isListening: Bool
    let isThinking: Bool
    let isSpeaking: Bool

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height

            ZStack {
                RoundedRectangle(cornerRadius: min(width, height) * 0.12, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.10, green: 0.14, blue: 0.20),
                                Color(red: 0.16, green: 0.23, blue: 0.30)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: min(width, height) * 0.12, style: .continuous)
                            .stroke(panelColor.opacity(0.26), lineWidth: 2)
                    )
                    .shadow(color: panelColor.opacity(0.18), radius: 28, y: 10)

                VStack(spacing: height * 0.12) {
                    antenna
                        .offset(y: -height * 0.14)

                    HStack(spacing: width * 0.12) {
                        RobotEyeView(tint: panelColor, isThinking: isThinking, isSpeaking: isSpeaking)
                        RobotEyeView(tint: panelColor, isThinking: isThinking, isSpeaking: isSpeaking)
                    }

                    RobotMouthView(openAmount: mouthOpen, tint: panelColor)
                        .frame(width: width * 0.36, height: height * 0.18)

                    HStack(spacing: 10) {
                        ForEach(0..<8, id: \.self) { _ in
                            Circle()
                                .fill(panelColor.opacity(0.17))
                                .frame(width: 4, height: 4)
                        }
                    }
                }
                .padding(.top, height * 0.14)
                .padding(.bottom, height * 0.08)
            }
        }
        .drawingGroup()
    }

    private var panelColor: Color {
        if isSpeaking {
            return Color(red: 1.0, green: 0.64, blue: 0.24)
        }
        if isThinking {
            return Color(red: 0.98, green: 0.84, blue: 0.24)
        }
        if isListening {
            return Color(red: 0.06, green: 0.88, blue: 0.86)
        }
        return Color(red: 0.68, green: 0.90, blue: 0.98)
    }

    private var antenna: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color.white.opacity(0.22))
                .frame(width: 10, height: 56)

            Circle()
                .fill(panelColor)
                .frame(width: 34, height: 34)
                .overlay(
                    Circle()
                        .stroke(.white.opacity(0.32), lineWidth: 1.5)
                )
                .shadow(color: panelColor.opacity(0.6 + audioLevel * 0.2), radius: 16)
        }
    }
}

private struct RobotEyeView: View {
    let tint: Color
    let isThinking: Bool
    let isSpeaking: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.black.opacity(0.34))
                .frame(width: 168, height: 112)

            if isThinking {
                Capsule()
                    .fill(tint.opacity(0.95))
                    .frame(width: 84, height: 14)
                    .shadow(color: tint.opacity(0.5), radius: 10)
            } else {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                tint.opacity(0.96),
                                .white.opacity(isSpeaking ? 0.95 : 0.78)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: 96, height: isSpeaking ? 62 : 54)
                    .shadow(color: tint.opacity(0.42), radius: 12)
            }
        }
    }
}

private struct RobotMouthView: View {
    let openAmount: Double
    let tint: Color

    private let pattern: [CGFloat] = [0.32, 0.6, 0.95, 0.6, 0.32]

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            ForEach(Array(pattern.enumerated()), id: \.offset) { item in
                let factor = item.element
                Capsule()
                    .fill(tint)
                    .frame(width: 18, height: max(18, 18 + (110 * factor * openAmount)))
                    .shadow(color: tint.opacity(0.24), radius: 8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.black.opacity(0.38))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(tint.opacity(0.18), lineWidth: 1)
                )
        )
    }
}
