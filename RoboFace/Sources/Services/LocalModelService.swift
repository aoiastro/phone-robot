import Foundation
import LocalLLMClient
import LocalLLMClientLlama

enum LocalModelServiceError: LocalizedError {
    case missingRepositoryID

    var errorDescription: String? {
        switch self {
        case .missingRepositoryID:
            return "Hugging Face のリポジトリ ID を入力してください。"
        }
    }
}

actor LocalModelService {
    private var session: LLMSession?
    private var sessionSignature = ""
    private let resolver = HuggingFaceModelResolver()

    func warmUp(
        settings: AssistantSettings,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws {
        let model = try await makeModel(from: settings)
        try await model.downloadModel { rawProgress in
            progress(max(0.0, min(1.0, Double(rawProgress))))
        }
        try await prepareSessionIfNeeded(with: model, settings: settings)
        progress(1.0)
    }

    func respond(
        to prompt: String,
        settings: AssistantSettings,
        progress: @escaping @Sendable (Double) -> Void = { _ in }
    ) async throws -> String {
        let model = try await makeModel(from: settings)
        try await model.downloadModel { rawProgress in
            progress(max(0.0, min(1.0, Double(rawProgress))))
        }
        let session = try await prepareSessionIfNeeded(with: model, settings: settings)
        session.messages = [.system(settings.systemPrompt)]
        progress(1.0)
        return try await session.respond(to: prompt)
    }

    private func prepareSessionIfNeeded(
        with model: LLMSession.DownloadModel,
        settings: AssistantSettings
    ) async throws -> LLMSession {
        let signature = signature(for: settings)
        if let session, sessionSignature == signature {
            session.messages = [.system(settings.systemPrompt)]
            return session
        }

        let newSession = LLMSession(model: model)
        newSession.messages = [.system(settings.systemPrompt)]
        session = newSession
        sessionSignature = signature
        return newSession
    }

    private func makeModel(from settings: AssistantSettings) async throws -> LLMSession.DownloadModel {
        guard !settings.trimmedRepositoryID.isEmpty else {
            throw LocalModelServiceError.missingRepositoryID
        }

        let modelFilename = if settings.trimmedFilename.isEmpty {
            try await resolver.resolveGGUFFilename(repositoryID: settings.trimmedRepositoryID)
        } else {
            settings.trimmedFilename
        }

        return .llama(
            id: settings.trimmedRepositoryID,
            model: modelFilename,
            parameter: .init(
                temperature: 0.7,
                topK: 40,
                topP: 0.9
            )
        )
    }

    private func signature(for settings: AssistantSettings) -> String {
        [
            settings.backend.rawValue,
            settings.trimmedRepositoryID,
            settings.trimmedFilename,
            settings.systemPrompt
        ].joined(separator: "::")
    }
}
