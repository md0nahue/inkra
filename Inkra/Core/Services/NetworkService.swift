import Foundation

protocol NetworkServiceProtocol {
    func request<T: Codable>(_ endpoint: APIEndpoint, responseType: T.Type) async throws -> T
    func requestData(_ endpoint: APIEndpoint) async throws -> Data
    func upload(data: Data, to url: URL) async throws
}

@available(iOS 15.0, macOS 12.0, *)
class NetworkService: NetworkServiceProtocol {
    nonisolated static let shared = NetworkService()
    
    private let session: URLSession
    private let baseURL: String
    
    private init(baseURL: String? = nil, session: URLSession = .shared) {
        // Use EnvironmentConfig for runtime-configurable URL
        self.baseURL = baseURL ?? EnvironmentConfig.currentAPIBaseURL
        self.session = session
        
        // Log the API configuration on initialization
        print("🌐 NetworkService initialized with baseURL: \(self.baseURL)")
        if EnvironmentConfig.isUsingStagingAPI {
            print("⚠️ Using STAGING API")
        } else if EnvironmentConfig.isUsingLocalhost {
            print("🏠 Using LOCALHOST API")
        }
    }
    
    func request<T: Codable>(_ endpoint: APIEndpoint, responseType: T.Type) async throws -> T {
        print("\n🌐 NETWORK REQUEST DEBUG")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        let correlationId = UUID().uuidString
        print("🎯 REQUEST DETAILS:")
        print("   - Endpoint: \(endpoint.path)")
        print("   - Method: \(endpoint.method.rawValue)")
        print("   - Response Type: \(T.self)")
        print("   - Correlation ID: \(correlationId)")
        
        let url = try buildURL(for: endpoint)
        print("   - Full URL: \(url.absoluteString)")
        let request = try await buildRequest(for: endpoint, url: url, correlationId: correlationId)
        
        if let httpBody = request.httpBody {
            print("   - Body Size: \(httpBody.count) bytes")
            if let bodyString = String(data: httpBody, encoding: .utf8) {
                let truncated = bodyString.count > 500 ? String(bodyString.prefix(500)) + "..." : bodyString
                print("   - Body Preview: \(truncated)")
            }
        } else {
            print("   - Body: nil")
        }
        
        print("   - Headers: \(request.allHTTPHeaderFields ?? [:])")
        
        // Log the request in debug builds with correlation ID
        ErrorLogger.shared.logNetworkRequest(
            endpoint.path,
            responseType: T.self,
            correlationId: correlationId
        )
        
        // Enhanced logging with full request details
        ErrorLogger.shared.logNetworkRequestWithHeaders(
            url: url.absoluteString,
            method: request.httpMethod ?? "UNKNOWN",
            headers: request.allHTTPHeaderFields ?? [:],
            body: request.httpBody,
            correlationId: correlationId
        )
        
        let (data, response) = try await session.data(for: request)
        
        // Log the response in debug builds
        if let httpResponse = response as? HTTPURLResponse {
            ErrorLogger.shared.logNetworkResponse(
                url: url.absoluteString,
                statusCode: httpResponse.statusCode,
                headers: httpResponse.allHeaderFields as? [String: String] ?? [:],
                data: data
            )
            
            // Enhanced logging with full response details
            ErrorLogger.shared.logNetworkResponseWithHeaders(
                url: url.absoluteString,
                statusCode: httpResponse.statusCode,
                headers: httpResponse.allHeaderFields as? [String: String] ?? [:],
                data: data,
                correlationId: correlationId
            )
        }
        
        do {
            try validateResponse(response, data: data)
            
            let decoder = JSONDecoder()
            // Automatically convert snake_case (e.g., project_id) to camelCase (e.g., projectId)
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            decoder.dateDecodingStrategy = .custom { decoder in
                let container = try decoder.singleValueContainer()
                let dateString = try container.decode(String.self)
                
                // Try multiple ISO8601 formatters to handle Rails variations
                
                // Try ISO8601DateFormatter variants
                let iso8601Formatters: [ISO8601DateFormatter] = [
                    {
                        let formatter = ISO8601DateFormatter()
                        return formatter
                    }(),
                    {
                        let formatter = ISO8601DateFormatter()
                        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                        return formatter
                    }()
                ]
                
                for formatter in iso8601Formatters {
                    if let date = formatter.date(from: dateString) {
                        return date
                    }
                }
                
                // Try DateFormatter variants
                let dateFormatters: [DateFormatter] = [
                    {
                        let formatter = DateFormatter()
                        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
                        formatter.timeZone = TimeZone(abbreviation: "UTC")
                        return formatter
                    }(),
                    {
                        let formatter = DateFormatter()
                        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
                        formatter.timeZone = TimeZone(abbreviation: "UTC")
                        return formatter
                    }()
                ]
                
                for formatter in dateFormatters {
                    if let date = formatter.date(from: dateString) {
                        return date
                    }
                }
                
                // If all formatters fail, log the problematic date string and throw error
                ErrorLogger.shared.logError(
                    NetworkError.decodingError(DecodingError.dataCorrupted(
                        DecodingError.Context(
                            codingPath: decoder.codingPath,
                            debugDescription: "Cannot decode date string: '\(dateString)'"
                        )
                    )),
                    context: "Date decoding failure",
                    additionalData: [
                        "dateString": dateString,
                        "attemptedFormats": [
                            "ISO8601 standard",
                            "ISO8601 with fractional seconds", 
                            "yyyy-MM-dd'T'HH:mm:ss.SSSZ",
                            "yyyy-MM-dd'T'HH:mm:ssZ"
                        ]
                    ]
                )
                
                throw DecodingError.dataCorrupted(
                    DecodingError.Context(
                        codingPath: decoder.codingPath,
                        debugDescription: "Cannot decode date string: '\(dateString)'"
                    )
                )
            }
            
            do {
                return try decoder.decode(T.self, from: data)
            } catch let error {
                // Use enhanced decoding error logging with correlation ID if it's a DecodingError
                if let decodingError = error as? DecodingError {
                    ErrorLogger.shared.logDecodingError(
                        decodingError,
                        for: T.self,
                        data: data,
                        url: url.absoluteString,
                        correlationId: correlationId
                    )
                }
                
                // Re-throw the original error to maintain existing behavior
                throw error
            }
        } catch {
            let mappedError = mapError(error)
            
            // Enhanced JSON structure analysis for debugging
            var jsonAnalysis: [String: Any] = [:]
            
            if let jsonObject = try? JSONSerialization.jsonObject(with: data, options: []) {
                if let jsonDict = jsonObject as? [String: Any] {
                    jsonAnalysis["type"] = "Dictionary"
                    jsonAnalysis["keys"] = Array(jsonDict.keys).sorted()
                    jsonAnalysis["keyCount"] = jsonDict.count
                    
                    // Show sample values for each key (truncated for readability)
                    var keyValues: [String: String] = [:]
                    for (key, value) in jsonDict {
                        let valueString = String(describing: value)
                        let truncatedValue = valueString.count > 100 ? String(valueString.prefix(100)) + "..." : valueString
                        keyValues[key] = "\(type(of: value)): \(truncatedValue)"
                    }
                    jsonAnalysis["keyValues"] = keyValues
                    
                    // Detailed analysis for common error patterns
                    if let decodingError = error as? DecodingError {
                        jsonAnalysis["decodingErrorContext"] = analyzeDecodingErrorContext(decodingError, jsonData: jsonDict)
                    }
                    
                } else if let jsonArray = jsonObject as? [Any] {
                    jsonAnalysis["type"] = "Array"
                    jsonAnalysis["count"] = jsonArray.count
                    
                    if let firstElement = jsonArray.first {
                        jsonAnalysis["firstElementType"] = "\(type(of: firstElement))"
                        let firstElementString = String(describing: firstElement)
                        jsonAnalysis["firstElement"] = firstElementString.count > 200 ? String(firstElementString.prefix(200)) + "..." : firstElementString
                        
                        // If it's an array of dictionaries, analyze the structure
                        if let firstDict = firstElement as? [String: Any] {
                            jsonAnalysis["arrayElementKeys"] = Array(firstDict.keys).sorted()
                            jsonAnalysis["arrayElementKeyCount"] = firstDict.count
                        }
                    }
                    
                    // If we have decoding error and it's an array, check if elements are missing expected keys
                    if let decodingError = error as? DecodingError {
                        jsonAnalysis["decodingErrorContext"] = analyzeArrayDecodingError(decodingError, jsonArray: jsonArray)
                    }
                } else {
                    jsonAnalysis["type"] = "\(type(of: jsonObject))"
                    jsonAnalysis["value"] = "\(jsonObject)"
                }
            } else {
                jsonAnalysis["error"] = "Unable to parse as JSON"
                let rawPreview = String(data: data.prefix(500), encoding: .utf8) ?? "Non-UTF8 data"
                jsonAnalysis["rawDataPreview"] = rawPreview
                jsonAnalysis["dataSize"] = "\(data.count) bytes"
            }
            
            // Enhanced error logging with context and JSON analysis
            ErrorLogger.shared.logError(
                mappedError,
                context: "NetworkService.request(\(endpoint.path))",
                additionalData: [
                    "url": url.absoluteString,
                    "method": endpoint.method.rawValue,
                    "responseType": String(describing: T.self),
                    "jsonAnalysis": jsonAnalysis,
                    "rawJSON": String(data: data, encoding: .utf8) ?? "Unable to decode as UTF-8"
                ]
            )
            
            throw mappedError
        }
    }
    
    /// Enhanced request method with graceful error handling for decoding failures
    /// Returns nil if decoding fails instead of throwing, useful for non-critical requests
    func requestSafely<T: Codable>(_ endpoint: APIEndpoint, responseType: T.Type) async -> T? {
        do {
            return try await request(endpoint, responseType: responseType)
        } catch {
            // Log the error but return nil instead of crashing
            ErrorLogger.shared.logError(
                error,
                context: "Safe request failed for \(endpoint.path)",
                additionalData: [
                    "responseType": String(describing: T.self),
                    "endpoint": endpoint.path,
                    "method": endpoint.method.rawValue,
                    "gracefulFailure": true
                ]
            )
            
            // Check if this is a decoding error that we can provide more guidance on
            if let networkError = error as? NetworkError,
               case .decodingError(let decodingError) = networkError {
                ErrorLogger.shared.logError(
                    decodingError,
                    context: "Graceful decoding failure - returning nil",
                    additionalData: [
                        "suggestion": "Check API contract documentation for \(endpoint.path)",
                        "responseType": String(describing: T.self)
                    ]
                )
            }
            
            return nil
        }
    }
    
    func requestData(_ endpoint: APIEndpoint) async throws -> Data {
        let correlationId = UUID().uuidString
        let url = try buildURL(for: endpoint)
        let request = try await buildRequest(for: endpoint, url: url, correlationId: correlationId)
        
        // Log the request in debug builds
        ErrorLogger.shared.logNetworkRequest(
            url: url.absoluteString,
            method: endpoint.method.rawValue,
            headers: request.allHTTPHeaderFields ?? [:],
            body: request.httpBody
        )
        
        let (data, response) = try await session.data(for: request)
        
        // Log the response in debug builds
        if let httpResponse = response as? HTTPURLResponse {
            ErrorLogger.shared.logNetworkResponse(
                url: url.absoluteString,
                statusCode: httpResponse.statusCode,
                headers: httpResponse.allHeaderFields as? [String: String] ?? [:],
                data: data
            )
        }
        
        do {
            try validateResponse(response, data: data)
            return data
        } catch {
            let mappedError = mapError(error)
            
            // Enhanced error logging with context
            ErrorLogger.shared.logError(
                mappedError,
                context: "NetworkService.requestData(\(endpoint.path))",
                additionalData: [
                    "url": url.absoluteString,
                    "method": endpoint.method.rawValue,
                    "dataSize": "\(data.count) bytes"
                ]
            )
            
            throw mappedError
        }
    }
    
    func upload(data: Data, to url: URL) async throws {
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        // For S3 presigned URLs, use the correct content type
        request.setValue("audio/m4a", forHTTPHeaderField: "Content-Type")
        request.httpBody = data
        
        // Log upload attempt
        ErrorLogger.shared.logNetworkRequest(
            url: url.absoluteString,
            method: "PUT",
            headers: request.allHTTPHeaderFields ?? [:],
            body: nil // Don't log the actual audio data
        )
        
        do {
            let (responseData, response) = try await session.data(for: request)
            
            // Log the response
            ErrorLogger.shared.logNetworkResponse(
                url: url.absoluteString,
                statusCode: (response as? HTTPURLResponse)?.statusCode ?? -1,
                headers: (response as? HTTPURLResponse)?.allHeaderFields as? [String: String] ?? [:],
                data: responseData
            )
            
            try validateResponse(response, data: responseData)
        } catch {
            ErrorLogger.shared.logError(
                error,
                context: "Upload failed to \(url.absoluteString)",
                additionalData: [
                    "dataSize": "\(data.count)",
                    "errorType": "\(type(of: error))"
                ]
            )
            throw mapError(error)
        }
    }
    
    private func buildURL(for endpoint: APIEndpoint) throws -> URL {
        guard let url = URL(string: baseURL + endpoint.path) else {
            throw NetworkError.invalidURL
        }
        return url
    }
    
    private func buildRequest(for endpoint: APIEndpoint, url: URL, correlationId: String) async throws -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add correlation ID to header for server-side logging
        request.setValue(correlationId, forHTTPHeaderField: "X-Correlation-ID")
        
        // Add Authorization header if we have an access token (except for auth endpoints)
        if !endpoint.path.contains("/auth") {
            if let accessToken = await AuthService.shared.accessToken {
                request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            }
        }
        
        if let body = endpoint.body {
            let encoder = JSONEncoder()
            // Automatically convert camelCase (e.g., fileName) to snake_case (e.g., file_name)
            encoder.keyEncodingStrategy = .convertToSnakeCase
            encoder.dateEncodingStrategy = .custom { date, encoder in
                // Use ISO8601 format that Rails can consistently parse
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime]
                let dateString = formatter.string(from: date)
                
                var container = encoder.singleValueContainer()
                try container.encode(dateString)
            }
            request.httpBody = try encoder.encode(body)
        }
        
        return request
    }
    
    private func validateResponse(_ response: URLResponse, data: Data? = nil) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.unknown(NSError(domain: "Invalid response", code: 0))
        }
        
        switch httpResponse.statusCode {
        case 200...299:
            return
        case 401:
            // Handle unauthorized access by logging out the user
            Task { @MainActor in
                await AuthService.shared.handleUnauthorizedAccess()
            }
            throw NetworkError.unauthorized
        case 400...499:
            if let data = data, let errorMessage = parseErrorMessage(from: data) {
                throw NetworkError.validationError(errorMessage)
            }
            throw NetworkError.serverError(httpResponse.statusCode)
        case 500...599:
            throw NetworkError.serverError(httpResponse.statusCode)
        default:
            throw NetworkError.serverError(httpResponse.statusCode)
        }
    }
    
    private func mapError(_ error: Error) -> NetworkError {
        if error is DecodingError {
            return .decodingError(error)
        }
        
        if let networkError = error as? NetworkError {
            return networkError
        }
        
        let nsError = error as NSError
        switch nsError.code {
        case NSURLErrorNotConnectedToInternet, NSURLErrorNetworkConnectionLost:
            return .networkUnavailable
        case NSURLErrorTimedOut:
            return .timeout
        default:
            return .unknown(error)
        }
    }
    
    private func parseErrorMessage(from data: Data) -> String? {
        // Try to parse Rails validation errors format: ["Error message 1", "Error message 2"]
        if let errorArray = try? JSONSerialization.jsonObject(with: data) as? [String] {
            return errorArray.joined(separator: ", ")
        }
        
        // Try to parse standard error format: {"error": "message"}
        if let errorDict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let errorMessage = errorDict["error"] as? String {
            return errorMessage
        }
        
        // Try to parse Rails errors format: {"errors": ["message1", "message2"]}
        if let errorDict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let errors = errorDict["errors"] as? [String] {
            return errors.joined(separator: ", ")
        }
        
        return nil
    }
    
    // MARK: - Enhanced Error Analysis
    
    private func analyzeDecodingErrorContext(_ error: DecodingError, jsonData: [String: Any]) -> [String: Any] {
        var context: [String: Any] = [:]
        
        switch error {
        case .keyNotFound(let key, let decodingContext):
            context["errorType"] = "keyNotFound"
            context["missingKey"] = key.stringValue
            context["codingPath"] = decodingContext.codingPath.map { $0.stringValue }.joined(separator: " -> ")
            context["availableKeys"] = Array(jsonData.keys).sorted()
            context["debugDescription"] = decodingContext.debugDescription
            
            // Check if key exists with different casing
            let lowercasedKey = key.stringValue.lowercased()
            let similarKeys = jsonData.keys.filter { $0.lowercased().contains(lowercasedKey) || lowercasedKey.contains($0.lowercased()) }
            if !similarKeys.isEmpty {
                context["similarKeys"] = Array(similarKeys)
            }
            
        case .typeMismatch(let type, let decodingContext):
            context["errorType"] = "typeMismatch"
            context["expectedType"] = String(describing: type)
            context["codingPath"] = decodingContext.codingPath.map { $0.stringValue }.joined(separator: " -> ")
            context["debugDescription"] = decodingContext.debugDescription
            
        case .valueNotFound(let type, let decodingContext):
            context["errorType"] = "valueNotFound"
            context["expectedType"] = String(describing: type)
            context["codingPath"] = decodingContext.codingPath.map { $0.stringValue }.joined(separator: " -> ")
            context["debugDescription"] = decodingContext.debugDescription
            
        case .dataCorrupted(let decodingContext):
            context["errorType"] = "dataCorrupted"
            context["codingPath"] = decodingContext.codingPath.map { $0.stringValue }.joined(separator: " -> ")
            context["debugDescription"] = decodingContext.debugDescription
            
        @unknown default:
            context["errorType"] = "unknown"
            context["description"] = String(describing: error)
        }
        
        return context
    }
    
    private func analyzeArrayDecodingError(_ error: DecodingError, jsonArray: [Any]) -> [String: Any] {
        var context: [String: Any] = [:]
        
        switch error {
        case .keyNotFound(let key, let decodingContext):
            context["errorType"] = "keyNotFound"
            context["missingKey"] = key.stringValue
            context["codingPath"] = decodingContext.codingPath.map { $0.stringValue }.joined(separator: " -> ")
            
            // Find which array element has the issue
            let pathComponents = decodingContext.codingPath
            if let indexComponent = pathComponents.first(where: { $0.intValue != nil }),
               let elementIndex = indexComponent.intValue,
               elementIndex < jsonArray.count,
               let elementDict = jsonArray[elementIndex] as? [String: Any] {
                context["problemElementIndex"] = elementIndex
                context["problemElementKeys"] = Array(elementDict.keys).sorted()
                
                // Check if other elements have the missing key
                var elementsWithKey = 0
                var elementsWithoutKey = 0
                for (_, element) in jsonArray.enumerated() {
                    if let dict = element as? [String: Any] {
                        if dict[key.stringValue] != nil {
                            elementsWithKey += 1
                        } else {
                            elementsWithoutKey += 1
                        }
                    }
                }
                context["elementsWithKey"] = elementsWithKey
                context["elementsWithoutKey"] = elementsWithoutKey
            }
            
        default:
            context = analyzeDecodingErrorContext(error, jsonData: [:])
        }
        
        return context
    }
    
    // Convenience methods for common HTTP operations
    func post<T: Codable, R: Codable>(_ path: String, body: T) async throws -> R {
        let endpoint = SimpleEndpoint(path: path, method: .POST, body: body)
        return try await request(endpoint, responseType: R.self)
    }
    
    func get<T: Codable>(_ path: String) async throws -> T {
        let endpoint = SimpleEndpoint(path: path, method: .GET, body: nil as String?)
        return try await request(endpoint, responseType: T.self)
    }
    
    func patch<T: Codable, R: Codable>(_ path: String, body: T) async throws -> R {
        let endpoint = SimpleEndpoint(path: path, method: .PATCH, body: body)
        return try await request(endpoint, responseType: R.self)
    }
    
    func delete<T: Codable, R: Codable>(_ path: String, body: T) async throws -> R {
        let endpoint = SimpleEndpoint(path: path, method: .DELETE, body: body)
        return try await request(endpoint, responseType: R.self)
    }
    
    // User preferences methods
    func getUserPreferences() async throws -> UserPreferencesResponse {
        return try await get("/api/user_preferences")
    }
    
    func updateUserInterests(_ interests: [String]) async throws -> UserPreferencesResponse {
        let request = UpdateUserPreferencesRequest(
            userPreferences: UserPreferencesData(interests: interests)
        )
        return try await patch("/api/user_preferences", body: request)
    }
    
    // MARK: - Safe convenience methods for non-critical operations
    
    func postSafely<T: Codable, R: Codable>(_ path: String, body: T) async -> R? {
        let endpoint = SimpleEndpoint(path: path, method: .POST, body: body)
        return await requestSafely(endpoint, responseType: R.self)
    }
    
    func getSafely<T: Codable>(_ path: String) async -> T? {
        let endpoint = SimpleEndpoint(path: path, method: .GET, body: nil as String?)
        return await requestSafely(endpoint, responseType: T.self)
    }
    
    func patchSafely<T: Codable, R: Codable>(_ path: String, body: T) async -> R? {
        let endpoint = SimpleEndpoint(path: path, method: .PATCH, body: body)
        return await requestSafely(endpoint, responseType: R.self)
    }
}

// Simple endpoint implementation for convenience methods
private struct SimpleEndpoint<T: Codable>: APIEndpoint {
    let path: String
    let method: HTTPMethod
    let body: Codable?
    
    init(path: String, method: HTTPMethod, body: T? = nil) {
        self.path = path
        self.method = method
        self.body = body
    }
}

enum HTTPMethod: String {
    case GET = "GET"
    case POST = "POST"
    case PATCH = "PATCH"
    case PUT = "PUT"
    case DELETE = "DELETE"
}

protocol APIEndpoint {
    var path: String { get }
    var method: HTTPMethod { get }
    var body: Codable? { get }
}

