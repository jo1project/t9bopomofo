import Foundation

/// OpenAI-compatible chat completions → next-phrase suggestions (繁中).
actor LLMPredictor {
    static let shared = LLMPredictor()

    struct SuggestResult: Sendable {
        var words: [String]
        var errorMessage: String?
    }

    func suggest(after context: String, limit: Int = 5) async -> [String] {
        await suggestDetailed(after: context, limit: limit).words
    }

    func suggestDetailed(after context: String, limit: Int = 5) async -> SuggestResult {
        let settings = AppSettings.shared
        guard settings.canUseLLM else {
            if !settings.isSponsored {
                return SuggestResult(words: [], errorMessage: "需先單次贊助解鎖 LLM")
            }
            return SuggestResult(words: [], errorMessage: "未啟用或未填 API Key")
        }
        let trimmed = context.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return SuggestResult(words: [], errorMessage: "上文為空")
        }

        let base = settings.llmBaseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: base + "/chat/completions") else {
            return SuggestResult(words: [], errorMessage: "Base URL 無效")
        }

        let prompt = """
        你是繁體中文輸入法聯想引擎。根據使用者刚輸入的文字，預測接下來最可能的接續詞或短語。
        只回傳 JSON 字串陣列，例如 ["好的","可以","謝謝"]，不要其他說明。
        最多 \(limit) 個，每個不超過 8 字。上文：\(trimmed)
        """

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.timeoutInterval = 12
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(settings.llmAPIKey)", forHTTPHeaderField: "Authorization")

        let body: [String: Any] = [
            "model": settings.llmModel,
            "temperature": 0.4,
            "max_tokens": 256,
            "messages": [
                ["role": "system", "content": "只輸出 JSON 陣列。"],
                ["role": "user", "content": prompt],
            ],
        ]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            guard let http = response as? HTTPURLResponse else {
                return SuggestResult(words: [], errorMessage: "無 HTTP 回應")
            }
            guard (200..<300).contains(http.statusCode) else {
                let apiMsg = Self.parseAPIError(from: data) ?? String(data: data, encoding: .utf8) ?? ""
                let clipped = apiMsg.trimmingCharacters(in: .whitespacesAndNewlines)
                let detail = clipped.isEmpty ? "HTTP \(http.statusCode)" : "HTTP \(http.statusCode)：\(clipped.prefix(160))"
                return SuggestResult(words: [], errorMessage: detail)
            }
            let words = parseSuggestions(from: data, limit: limit)
            if words.isEmpty {
                return SuggestResult(words: [], errorMessage: "回應無法解析為詞陣列")
            }
            return SuggestResult(words: words, errorMessage: nil)
        } catch {
            return SuggestResult(words: [], errorMessage: error.localizedDescription)
        }
    }

    private static func parseAPIError(from data: Data) -> String? {
        guard
            let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let err = root["error"] as? [String: Any]
        else { return nil }
        if let message = err["message"] as? String { return message }
        if let code = err["code"] as? String { return code }
        return nil
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
        guard !text.isEmpty else { return [] }

        // Prefer JSON array; also accept {"words":[...]} / {"suggestions":[...]}
        if let start = text.firstIndex(of: "["), let end = text.lastIndex(of: "]"), start <= end {
            let jsonText = String(text[start...end])
            if let arr = try? JSONSerialization.jsonObject(with: Data(jsonText.utf8)) as? [Any] {
                return Self.dedupe(arr, limit: limit)
            }
        }
        if let start = text.firstIndex(of: "{"), let end = text.lastIndex(of: "}"), start <= end {
            let jsonText = String(text[start...end])
            if let obj = try? JSONSerialization.jsonObject(with: Data(jsonText.utf8)) as? [String: Any] {
                for key in ["words", "suggestions", "candidates", "data"] {
                    if let arr = obj[key] as? [Any] {
                        return Self.dedupe(arr, limit: limit)
                    }
                }
            }
        }
        return []
    }

    private static func dedupe(_ arr: [Any], limit: Int) -> [String] {
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
