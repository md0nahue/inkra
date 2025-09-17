import Foundation

extension Error {
    func logError(file: String = #file, function: String = #function, line: Int = #line) {
        LogManager.shared.error("\(self.localizedDescription)", file: file, function: function, line: line)
    }
}

// Extension for logging API responses
extension URLResponse {
    func logResponse(data: Data?, error: Error?) {
        guard let httpResponse = self as? HTTPURLResponse else { return }
        
        var logMessage = "API Response - Status: \(httpResponse.statusCode)"
        
        if let url = httpResponse.url {
            logMessage += ", URL: \(url.absoluteString)"
        }
        
        if let error = error {
            logMessage += ", Error: \(error.localizedDescription)"
            LogManager.shared.error(logMessage)
        } else if httpResponse.statusCode >= 400 {
            if let data = data, let responseString = String(data: data, encoding: .utf8) {
                logMessage += ", Response: \(responseString.prefix(500))"
            }
            LogManager.shared.warning(logMessage)
        } else {
            LogManager.shared.debug(logMessage)
        }
    }
}

// Extension for logging network requests
extension URLRequest {
    func logRequest() {
        var logMessage = "API Request"
        
        if let method = self.httpMethod {
            logMessage += " - Method: \(method)"
        }
        
        if let url = self.url {
            logMessage += ", URL: \(url.absoluteString)"
        }
        
        if let headers = self.allHTTPHeaderFields, !headers.isEmpty {
            // Don't log authorization headers for security
            let sanitizedHeaders = headers.filter { !$0.key.lowercased().contains("authorization") }
            if !sanitizedHeaders.isEmpty {
                logMessage += ", Headers: \(sanitizedHeaders)"
            }
        }
        
        LogManager.shared.debug(logMessage)
    }
}