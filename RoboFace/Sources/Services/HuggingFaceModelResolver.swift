import Foundation

enum HuggingFaceModelResolverError: LocalizedError {
    case invalidRepositoryID
    case noGGUFFileFound

    var errorDescription: String? {
        switch self {
        case .invalidRepositoryID:
            return "Hugging Face のリポジトリ ID が不正です。"
        case .noGGUFFileFound:
            return "このリポジトリで使えそうな .gguf ファイルを見つけられませんでした。ファイル名を指定してください。"
        }
    }
}

struct HuggingFaceModelResolver {
    func resolveGGUFFilename(repositoryID: String) async throws -> String {
        let trimmedID = repositoryID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedID.isEmpty else {
            throw HuggingFaceModelResolverError.invalidRepositoryID
        }

        let encodedID = trimmedID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? trimmedID
        guard let url = URL(string: "https://huggingface.co/api/models/\(encodedID)") else {
            throw HuggingFaceModelResolverError.invalidRepositoryID
        }

        let (data, response) = try await URLSession.shared.data(from: url)
        if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
            throw HuggingFaceModelResolverError.noGGUFFileFound
        }

        let payload = try JSONDecoder().decode(HuggingFaceModelResponse.self, from: data)
        let candidates = payload.siblings
            .map(\.rfilename)
            .filter { $0.lowercased().hasSuffix(".gguf") }

        guard let best = chooseBestGGUF(from: candidates) else {
            throw HuggingFaceModelResolverError.noGGUFFileFound
        }

        return best
    }

    private func chooseBestGGUF(from candidates: [String]) -> String? {
        candidates.max { lhs, rhs in
            score(lhs) < score(rhs)
        }
    }

    private func score(_ filename: String) -> Int {
        let lower = filename.lowercased()
        var value = 0

        if lower.contains("q4_k_m") { value += 1000 }
        if lower.contains("q4_0") { value += 900 }
        if lower.contains("q4") { value += 800 }
        if lower.contains("iq4") { value += 780 }
        if lower.contains("q5_k_m") { value += 700 }
        if lower.contains("q5") { value += 650 }
        if lower.contains("q6") { value += 500 }
        if lower.contains("q8") { value += 350 }
        if lower.contains("f16") { value += 150 }
        if lower.contains("bf16") { value += 120 }
        if lower.contains("instruct") { value += 60 }
        if lower.contains("chat") { value += 40 }
        if lower.contains("vision") || lower.contains("vl") || lower.contains("mmproj") { value -= 200 }
        if lower.contains("embed") || lower.contains("embedding") { value -= 400 }
        value -= filename.count / 6

        return value
    }
}

private struct HuggingFaceModelResponse: Decodable {
    let siblings: [HuggingFaceSibling]
}

private struct HuggingFaceSibling: Decodable {
    let rfilename: String
}
