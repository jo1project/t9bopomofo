import Foundation

/// Built-in OpenAI-compatible LLM provider presets for the settings UI.
enum LLMProviderPreset: String, CaseIterable, Identifiable {
    case groq
    case openai
    case openrouter
    case deepseek
    case together
    case xai
    case gemini
    case mistral
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .groq: return "Groq（常有免費額度）"
        case .openai: return "OpenAI"
        case .openrouter: return "OpenRouter"
        case .deepseek: return "DeepSeek"
        case .together: return "Together AI"
        case .xai: return "xAI（Grok）"
        case .gemini: return "Google Gemini"
        case .mistral: return "Mistral"
        case .custom: return "自訂"
        }
    }

    var note: String {
        switch self {
        case .groq: return "到 console.groq.com 申請 Key（gsk_…）"
        case .openai: return "需付費／有額度；platform.openai.com"
        case .openrouter: return "可選多模型；openrouter.ai"
        case .deepseek: return "platform.deepseek.com"
        case .together: return "api.together.ai"
        case .xai: return "console.x.ai（Grok）"
        case .gemini: return "Google AI Studio 的 API Key"
        case .mistral: return "console.mistral.ai"
        case .custom: return "自行填 Base URL／Model／Key"
        }
    }

    /// nil means leave field unchanged (custom).
    var exampleBaseURL: String? {
        switch self {
        case .groq: return "https://api.groq.com/openai/v1"
        case .openai: return "https://api.openai.com/v1"
        case .openrouter: return "https://openrouter.ai/api/v1"
        case .deepseek: return "https://api.deepseek.com/v1"
        case .together: return "https://api.together.ai/v1"
        case .xai: return "https://api.x.ai/v1"
        case .gemini: return "https://generativelanguage.googleapis.com/v1beta/openai"
        case .mistral: return "https://api.mistral.ai/v1"
        case .custom: return nil
        }
    }

    var exampleModel: String? {
        switch self {
        case .groq: return "groq/compound-mini"
        case .openai: return "gpt-4o-mini"
        case .openrouter: return "openai/gpt-4o-mini"
        case .deepseek: return "deepseek-chat"
        case .together: return "meta-llama/Meta-Llama-3.1-8B-Instruct-Turbo"
        case .xai: return "grok-3-mini"
        case .gemini: return "gemini-2.0-flash"
        case .mistral: return "mistral-small-latest"
        case .custom: return nil
        }
    }

    static func matching(baseURL: String) -> LLMProviderPreset {
        let u = baseURL.lowercased()
        if u.contains("api.groq.com") { return .groq }
        if u.contains("api.openai.com") { return .openai }
        if u.contains("openrouter.ai") { return .openrouter }
        if u.contains("api.deepseek.com") { return .deepseek }
        if u.contains("api.together.") { return .together }
        if u.contains("api.x.ai") { return .xai }
        if u.contains("generativelanguage.googleapis.com") { return .gemini }
        if u.contains("api.mistral.ai") { return .mistral }
        if u.isEmpty || u.contains("api.openai.com") { return .openai }
        return .custom
    }
}
