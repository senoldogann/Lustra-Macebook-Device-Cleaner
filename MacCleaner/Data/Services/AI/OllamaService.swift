import Foundation
import os

/// Analysis result from Ollama AI
struct FileAnalysis: Codable, Equatable, Sendable {
    let status: AnalysisStatus
    let description: String
    let consequences: String
    let safeToDelete: Bool
    
    // Uses shared AnalysisStatus from Domain/Models

}

/// Ollama Cloud API Service
/// Reads configuration from OllamaConfig.plist for security.
actor OllamaService {
    static let shared = OllamaService()
    
    private var apiHost: String = ""
    private var apiKey: String = ""
    private var model: String = ""
    
    private let defaultsKey = "OllamaAPIKey_UserOverride"
    
    private init() {
        // Load configuration immediately
        // 1. Check User Override
        if let userKey = UserDefaults.standard.string(forKey: defaultsKey), !userKey.isEmpty {
            self.apiKey = userKey
            Logger.lifecycle.info("Using User Configured API Key")
        }
        // 2. Fallback to Plist
        else if let path = Bundle.main.path(forResource: "OllamaConfig", ofType: "plist"),
                let dict = NSDictionary(contentsOfFile: path) as? [String: Any] {
            
            self.apiKey = dict["OllamaAPIKey"] as? String ?? ""
            self.apiHost = dict["OllamaAPIHost"] as? String ?? AppConstants.AI.defaultBaseURL
            self.model = dict["OllamaModel"] as? String ?? AppConstants.AI.defaultModel
        }
        
        if apiKey.isEmpty {
            Logger.lifecycle.warning("WARNING: Ollama API Key is empty in config.")
        }
    }
    
    /// Update API Key dynamically from Settings
    func updateAPIKey(_ newKey: String) {
        self.apiKey = newKey
        UserDefaults.standard.set(newKey, forKey: defaultsKey)
        Logger.lifecycle.info("Ollama API Key updated by user")
    }
    
    private func sanitizeInput(_ input: String) -> String {
        // Remove characters that could break Markdown or JSON context
        // This is a basic sanitizer. For high security, consider strict alphanumeric + safe symbols allowlist.
        var sanitized = input.replacingOccurrences(of: "```", with: "'''")
        sanitized = sanitized.replacingOccurrences(of: "\"", with: "'")
        sanitized = sanitized.replacingOccurrences(of: "\\", with: "\\\\")
        
        // Truncate to reasonable length to prevent token overflow attacks
        return String(sanitized.prefix(256))
    }

    /// Analyze a file or folder to determine if it's safe to delete
    func analyzeFile(name: String, path: String, size: Int64, isDirectory: Bool) async -> FileAnalysis {
        // Validation choke point
        guard !apiKey.isEmpty else {
            return FileAnalysis(status: .unknown, description: "Missing API Configuration", consequences: "Configure API key in settings", safeToDelete: false)
        }
        
        let sizeFormatted = ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
        let type = isDirectory ? "folder" : "file"
        
        let safeName = sanitizeInput(name)
        let safePath = sanitizeInput(path)
        
        let prompt = """
        You are a Mac Tech Expert. Analyze this file/folder.
        1. Explain what it does in simple terms.
        2. EXPLICITLY state what happens if deleted.
        
        Name: \(safeName)
        Path: \(safePath)
        Size: \(sizeFormatted)
        Type: \(type)
        
        Return ONLY valid JSON.
        {
            "status": "safe" or "review",
            "description": "What it is",
            "consequences": "What happens if deleted",
            "safeToDelete": true or false
        }
        """
        
        do {
            let response = try await callOllamaAPI(prompt: prompt)
            return parseAnalysisResponse(response)
        } catch {
            Logger.scan.error("Ollama API Analysis Failed: \(error.localizedDescription)")
            return FileAnalysis(status: .unknown, description: "Analysis Service Unavailable", consequences: "Try again later", safeToDelete: false)
        }
    }
    
    private func callOllamaAPI(prompt: String) async throws -> String {
        guard let url = URL(string: "\(apiHost)/api/generate") else {
            throw OllamaError.invalidURL 
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 60 // Increased timeout for longer generation
        
        let body: [String: Any] = [
            "model": model,
            "prompt": prompt,
            "stream": false,
            "options": [
                "temperature": 0.1,
                "num_predict": 1024, // Increased from 150 to prevent truncation
                "top_k": 20,
                "top_p": 0.9
            ]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OllamaError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            Logger.scan.error("API Error \(httpResponse.statusCode): \(errorBody)")
            throw OllamaError.apiError(statusCode: httpResponse.statusCode, message: errorBody)
        }
        
        // Robust JSON parsing
        struct GenerateResponse: Decodable {
            let response: String
        }
        
        let decoded = try JSONDecoder().decode(GenerateResponse.self, from: data)
        return decoded.response
    }
    
    private func parseAnalysisResponse(_ response: String) -> FileAnalysis {
        Logger.scan.info("DEBUG: Raw AI Response: \(response)")
        
        var jsonString = response.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 1. Try to extract from markdown code blocks first (most reliable)
        // Matches ```json { ... } ``` or just ``` { ... } ```
        let pattern = "```(?:json)?\\s*(\\{[\\s\\S]*?\\})\\s*```"
        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: jsonString, range: NSRange(jsonString.startIndex..., in: jsonString)),
           let range = Range(match.range(at: 1), in: jsonString) {
            jsonString = String(jsonString[range])
        } 
        // 2. Fallback: Try to find the first '{' and last '}'
        else if let startRange = jsonString.range(of: "{"),
                let endRange = jsonString.range(of: "}", options: .backwards) {
            jsonString = String(jsonString[startRange.lowerBound..<endRange.upperBound])
        }
        
        Logger.scan.info("DEBUG: Extracted JSON: \(jsonString)")
        
        guard let jsonData = jsonString.data(using: .utf8) else {
            return defaultAnalysis()
        }
        
        do {
            let result = try JSONDecoder().decode(AnalysisResponse.self, from: jsonData)
            
            let status: AnalysisStatus
            switch result.status.lowercased() {
            case "safe": status = .safe
            case "review": status = .review
            default: status = .unknown
            }
            
            return FileAnalysis(
                status: status,
                description: result.description,
                consequences: result.consequences ?? "No specific consequence listed.",
                safeToDelete: result.safeToDelete
            )
        } catch {
            Logger.scan.error("JSON Parse Error: \(error.localizedDescription) - Content was: \(jsonString)")
            return defaultAnalysis()
        }
    }
    
    private func defaultAnalysis() -> FileAnalysis {
        FileAnalysis(status: .unknown, description: "Interpretation Failed", consequences: "Unknown", safeToDelete: false)
    }
    
    // Internal struct for matching JSON response from AI
    private struct AnalysisResponse: Codable {
        let status: String
        let description: String
        let consequences: String? // Optional in case model misses it
        let safeToDelete: Bool
    }
    
    enum OllamaError: Error, LocalizedError {
        case invalidURL
        case invalidResponse
        case apiError(statusCode: Int, message: String)
        
        var errorDescription: String? {
            switch self {
            case .invalidURL: return "Invalid API URL Configuration"
            case .invalidResponse: return "Invalid response structure from Server"
            case .apiError(let code, let msg): return "Server Error \(code): \(msg)"
            }
        }
    }
}
