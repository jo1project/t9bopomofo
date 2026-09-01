import Foundation

/// OpenAI-compatible chat completions → next-phrase suggestions (繁中).
actor LLMPredictor {
    static let shared = LLMPredictor()

    func suggest(after context: String, limit: Int = 5) async -> [String] {
        let settings = AppSettings.shared
        guard settings.canUseLLM else { return [] }
        let trimmed = context.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        let base = settings.llmBaseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: base + "/chat/completions") else { return [] }

        let prompt = """
        你是繁體中文輸入法聯想引擎。根據使用者刚輸入的文字，預測接下來最可能的接續詞或短語。
        只回傳 JSON 字串陣列，例如 ["好的","可以","謝謝"]，不要其他說明。
        最多 \(limit) 個，每個不超過 8 字。上文：\(trimmed)
        """

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.timeoutInterval = 8
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(settings.llmAPIKey)", forHTTPHeaderField: "Authorization")

        let body: [String: Any] = [
            "model": settings.llmModel,
            "temperature": 0.4,
            "max_tokens": 120,
            "messages": [
                ["role": "system", "content": "只輸出 JSON 陣列。"],
                ["role": "user", "content": prompt],
            ],
        ]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                return []
            }
            return parseSuggestions(from: data, limit: limit)
        } catch {
            return []
        }
    }

    private func parseSuggestions(from data: Data, limit: Int) -> [String] {
        // OpenAI-style: choices[0].message.content
        guard
            let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let choices = root["choices"] as? [[String: Any]],
            let message = choices.first?["message"] as? [String: Any],
            let content = message["content"] as? String
        else { return [] }

        let text = content.trimmingCharacters(in: .whitespacesAndNewlines)
        // Strip markdown fences if any
        var jsonText = text
        if let start = text.firstIndex(of: "["), let end = text.lastIndex(of: "]"), start <= end {
            jsonText = String(text[start...end])
        }
        guard let arr = try? JSONSerialization.jsonObject(with: Data(jsonText.utf8)) as? [Any] else {
            return []
        }
        var out: [String] = []
        var seen = Set<String>()
        for item in arr {
            let s = "\(item)".trimmingCharacters(in: .whitespacesAndNewlines)
            guard !s.isEmpty, s.count <= 12, !seen.contains(s) else { continue }
            seen.insert(s)
            out.append(s)
            if out.count >= limit { break }
        }
        return out
    }
}
