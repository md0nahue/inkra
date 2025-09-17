import Foundation
import os.log
import UIKit

class ErrorLogger {
    static let shared = ErrorLogger()
    
    // Create specific loggers for different parts of the app
    private let generalLog = Logger(subsystem: "com.inkra.app", category: "General")
    private let networkLog = Logger(subsystem: "com.inkra.app", category: "Network")
    private let navigationLog = Logger(subsystem: "com.inkra.app", category: "Navigation")
    private let fileManager = FileManager.default
    private let dateFormatter: DateFormatter
    
    private init() {
        dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        dateFormatter.timeZone = TimeZone.current
    }
    
    private var logFileURL: URL? {
        guard let documentsDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        return documentsDir.appendingPathComponent("inkra_debug_logs.log")
    }
    
    func logError(_ error: Error, context: String = "", additionalData: [String: Any] = [:]) {
        let timestamp = dateFormatter.string(from: Date())
        
        var logMessage = "[\(timestamp)] ERROR in \(context)\n"
        logMessage += "Error: \(error.localizedDescription)\n"
        
        // Special handling for NetworkError with detailed decoding information
        if let networkError = error as? NetworkError {
            logMessage += "Network Error Type: \(networkError)\n"
            
            if case .decodingError(let decodingError) = networkError {
                logMessage += "Decoding Error Details:\n"
                logMessage += formatDecodingError(decodingError)
            }
        }
        
        // Add additional context data
        if !additionalData.isEmpty {
            logMessage += "Additional Data:\n"
            for (key, value) in additionalData {
                logMessage += "  \(key): \(value)\n"
            }
        }
        
        logMessage += "Stack Trace:\n\(Thread.callStackSymbols.joined(separator: "\n"))\n"
        logMessage += "---\n\n"
        
        // Log to system log
        generalLog.error("\(logMessage)")
        
        // Write to file in development/debug builds
        #if DEBUG
        writeToLogFile(logMessage)
        #endif
    }
    
    func logNetworkRequest(url: String, method: String, headers: [String: String] = [:], body: Data? = nil) {
        #if DEBUG
        let timestamp = dateFormatter.string(from: Date())
        var logMessage = "[\(timestamp)] NETWORK REQUEST\n"
        logMessage += "URL: \(url)\n"
        logMessage += "Method: \(method)\n"
        
        if !headers.isEmpty {
            logMessage += "Headers:\n"
            for (key, value) in headers {
                // Redact sensitive headers
                let redactedValue = key.lowercased().contains("authorization") ? "[REDACTED]" : value
                logMessage += "  \(key): \(redactedValue)\n"
            }
        }
        
        if let body = body, let bodyString = String(data: body, encoding: .utf8) {
            logMessage += "Body: \(bodyString)\n"
        }
        
        logMessage += "---\n\n"
        writeToLogFile(logMessage)
        #endif
    }
    
    func logNetworkResponse(url: String, statusCode: Int, headers: [String: String] = [:], data: Data? = nil) {
        #if DEBUG
        let timestamp = dateFormatter.string(from: Date())
        var logMessage = "[\(timestamp)] NETWORK RESPONSE\n"
        logMessage += "URL: \(url)\n"
        logMessage += "Status Code: \(statusCode)\n"
        
        if !headers.isEmpty {
            logMessage += "Headers:\n"
            for (key, value) in headers {
                logMessage += "  \(key): \(value)\n"
            }
        }
        
        if let data = data, let responseString = String(data: data, encoding: .utf8) {
            logMessage += "Response Body: \(responseString)\n"
        }
        
        logMessage += "---\n\n"
        writeToLogFile(logMessage)
        #endif
    }
    
    
    private func formatDecodingError(_ error: Error) -> String {
        guard let decodingError = error as? DecodingError else {
            return "Unknown decoding error: \(error)\n"
        }
        
        var details = ""
        
        switch decodingError {
        case .typeMismatch(let type, let context):
            details += "Type mismatch for type \(type)\n"
            details += "Context: \(context.debugDescription)\n"
            details += "Coding path: \(context.codingPath.map { $0.stringValue }.joined(separator: " -> "))\n"
            
        case .valueNotFound(let type, let context):
            details += "Value not found for type \(type)\n"
            details += "Context: \(context.debugDescription)\n"
            details += "Coding path: \(context.codingPath.map { $0.stringValue }.joined(separator: " -> "))\n"
            
        case .keyNotFound(let key, let context):
            details += "Key '\(key.stringValue)' not found\n"
            details += "Context: \(context.debugDescription)\n"
            details += "Coding path: \(context.codingPath.map { $0.stringValue }.joined(separator: " -> "))\n"
            
        case .dataCorrupted(let context):
            details += "Data corrupted\n"
            details += "Context: \(context.debugDescription)\n"
            details += "Coding path: \(context.codingPath.map { $0.stringValue }.joined(separator: " -> "))\n"
            
        @unknown default:
            details += "Unknown decoding error: \(decodingError)\n"
        }
        
        return details
    }
    
    private func writeToLogFile(_ message: String) {
        guard let logFileURL = logFileURL else { return }
        
        do {
            if fileManager.fileExists(atPath: logFileURL.path) {
                let fileHandle = try FileHandle(forWritingTo: logFileURL)
                fileHandle.seekToEndOfFile()
                fileHandle.write(message.data(using: .utf8) ?? Data())
                fileHandle.closeFile()
            } else {
                try message.write(to: logFileURL, atomically: true, encoding: .utf8)
            }
        } catch {
            generalLog.error("Failed to write to log file: \(error.localizedDescription)")
        }
    }
    
    func getLogFileURL() -> URL? {
        return logFileURL
    }
    
    func clearLogs() {
        guard let logFileURL = logFileURL else { return }
        try? fileManager.removeItem(at: logFileURL)
    }
    
    #if DEBUG
    func printLogFilePath() {
        if let logFileURL = logFileURL {
            print("📁 Debug log file location: \(logFileURL.path)")
            print("📝 For 'could not read data' errors, check this file for detailed network request/response info and JSON structure analysis")
            print("🔍 Enhanced debugging: Navigation tracking, state changes, user actions, and performance metrics are logged")
        }
    }
    #endif
    
    // MARK: - Enhanced Navigation and Network Logging
    
    func logNavigation(to destination: String, from view: String) {
        let message = "NAVIGATING to \(destination) from \(view)"
        navigationLog.info("➡️ \(message)")
        writeToLogFile("[\(timestamp())] NAV: \(message)\n")
    }

    func logNavigationBlocked(reason: String, from view: String) {
        let message = "NAVIGATION BLOCKED from \(view). Reason: \(reason)"
        navigationLog.error("⛔️ \(message)")
        writeToLogFile("[\(timestamp())] NAV_BLOCK: \(message)\n")
    }
    
    func logViewAppearance(viewName: String, additionalData: [String: Any] = [:]) {
        let message = "VIEW APPEARED: \(viewName)"
        navigationLog.info("👁️ \(message)")
        
        var logEntry = "[\(timestamp())] VIEW_APPEAR: \(message)"
        if !additionalData.isEmpty {
            logEntry += " - Data: \(additionalData)"
        }
        writeToLogFile("\(logEntry)\n")
    }
    
    func logViewDisappearance(viewName: String, additionalData: [String: Any] = [:]) {
        let message = "VIEW DISAPPEARED: \(viewName)"
        navigationLog.info("👋 \(message)")
        
        var logEntry = "[\(timestamp())] VIEW_DISAPPEAR: \(message)"
        if !additionalData.isEmpty {
            logEntry += " - Data: \(additionalData)"
        }
        writeToLogFile("\(logEntry)\n")
    }
    
    func logStateChange(in view: String, from oldState: String, to newState: String, context: [String: Any] = [:]) {
        let message = "STATE CHANGE in \(view): \(oldState) → \(newState)"
        navigationLog.info("🔄 \(message)")
        
        var logEntry = "[\(timestamp())] STATE_CHANGE: \(message)"
        if !context.isEmpty {
            logEntry += " - Context: \(context)"
        }
        writeToLogFile("\(logEntry)\n")
    }
    
    func logUserAction(_ action: String, in view: String, details: [String: Any] = [:]) {
        let message = "USER ACTION in \(view): \(action)"
        navigationLog.info("👆 \(message)")
        
        var logEntry = "[\(timestamp())] USER_ACTION: \(message)"
        if !details.isEmpty {
            logEntry += " - Details: \(details)"
        }
        writeToLogFile("\(logEntry)\n")
    }
    
    func logNavigationExpectation(expected: String, actual: String?, view: String, success: Bool) {
        let actualStr = actual ?? "NONE"
        let status = success ? "✅" : "❌"
        let message = "NAV EXPECTATION \(status) in \(view): Expected=\(expected), Actual=\(actualStr)"
        
        if success {
            navigationLog.info("\(message)")
        } else {
            navigationLog.error("\(message)")
        }
        
        writeToLogFile("[\(timestamp())] NAV_EXPECT: \(message)\n")
    }
    
    func logNetworkRequest<T: Decodable>(_ endpoint: String, responseType: T.Type, correlationId: String) {
        #if DEBUG
        let message = """
        [NETWORK REQUEST]
        Correlation-ID: \(correlationId)
        URL: \(endpoint)
        Expected Response Type: \(String(describing: T.self))
        """
        networkLog.debug("\(message)")
        writeToLogFile("[\(timestamp())] \(message)\n")
        #endif
    }
    
    func logNetworkRequestWithHeaders(url: String, method: String, headers: [String: String], body: Data?, correlationId: String) {
        #if DEBUG
        var message = """
        [NETWORK REQUEST FULL]
        Correlation-ID: \(correlationId)
        URL: \(url)
        Method: \(method)
        Headers:
        """
        
        for (key, value) in headers {
            // Redact sensitive headers
            let redactedValue = key.lowercased().contains("authorization") ? "[REDACTED]" : value
            message += "  \(key): \(redactedValue)\n"
        }
        
        if let body = body, let bodyString = String(data: body, encoding: .utf8) {
            message += "Request Body:\n\(bodyString)\n"
        }
        
        networkLog.debug("\(message)")
        writeToLogFile("[\(timestamp())] \(message)\n")
        #endif
    }
    
    func logNetworkResponseWithHeaders(url: String, statusCode: Int, headers: [String: String], data: Data?, correlationId: String) {
        #if DEBUG
        var message = """
        [NETWORK RESPONSE FULL]
        Correlation-ID: \(correlationId)
        URL: \(url)
        Status Code: \(statusCode)
        Headers:
        """
        
        for (key, value) in headers {
            message += "  \(key): \(value)\n"
        }
        
        if let data = data, let responseString = String(data: data, encoding: .utf8) {
            message += "Response Body:\n\(responseString)\n"
        }
        
        if statusCode >= 200 && statusCode < 300 {
            networkLog.debug("\(message)")
        } else {
            networkLog.error("\(message)")
        }
        writeToLogFile("[\(timestamp())] \(message)\n")
        #endif
    }
    
    func logDecodingError<T>(_ error: DecodingError, for type: T.Type, data: Data, url: String, correlationId: String) {
        #if DEBUG
        let rawJSON = String(data: data, encoding: .utf8) ?? "Invalid UTF-8 data"
        let message = """
        [DECODING ERROR]
        Correlation-ID: \(correlationId)
        URL: \(url)
        Failed to decode \(String(describing: T.self)).
        Error: \(formatDecodingError(error))
        RAW JSON RECEIVED:
        ------------------------------------------
        \(rawJSON)
        ------------------------------------------
        """
        networkLog.error("\(message)")
        writeToLogFile("[\(timestamp())] \(message)\n")
        #endif
    }
    
    private func timestamp() -> String {
        return dateFormatter.string(from: Date())
    }
    
    // MARK: - Debug Helpers
    
    func flushLogs() {
        // Force flush any pending logs
        #if DEBUG
        writeToLogFile("[\(timestamp())] LOG_FLUSH: Manual flush requested\n")
        #endif
    }
    
    func logSessionStart() {
        #if DEBUG
        let sessionInfo = """
        ========================================
        SESSION STARTED: \(timestamp())
        App Version: \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] ?? "Unknown")
        Build: \(Bundle.main.infoDictionary?["CFBundleVersion"] ?? "Unknown")
        Device: \(UIDevice.current.model)
        iOS Version: \(UIDevice.current.systemVersion)
        ========================================
        """
        writeToLogFile(sessionInfo)
        generalLog.info("New debugging session started")
        #endif
    }

    // MARK: - Enhanced Data Reading Error Logging
    
    func logDataReadingError(_ error: Error, operation: String, additionalContext: [String: Any] = [:]) {
        var context = additionalContext
        context["operation"] = operation
        context["isDataReadingError"] = true
        
        // Check if this is the specific error we're tracking
        let errorString = error.localizedDescription.lowercased()
        if errorString.contains("couldn't be read") || errorString.contains("could not read") || errorString.contains("missing") {
            context["matchesKnownPattern"] = true
            context["errorPattern"] = "data_reading_error"
        }
        
        logError(error, context: "Data Reading Error - \(operation)", additionalData: context)
    }
    
    // MARK: - Critical Bug Detection and Recovery
    
    func logCriticalBugDetected(_ bugDescription: String, in view: String, recoveryAction: String?, stackTrace: [String] = []) {
        let message = """
        [CRITICAL BUG DETECTED]
        View: \(view)
        Description: \(bugDescription)
        Recovery Action: \(recoveryAction ?? "None")
        Stack Trace: \(stackTrace.isEmpty ? "Not available" : stackTrace.joined(separator: "\n"))
        """
        
        generalLog.error("🚨 \(message)")
        writeToLogFile("[\(timestamp())] CRITICAL_BUG: \(message)\n")
    }
    
    func logUnexpectedState(_ description: String, in view: String, expectedState: String, actualState: String, context: [String: Any] = [:]) {
        let message = """
        [UNEXPECTED STATE]
        View: \(view)
        Description: \(description)
        Expected: \(expectedState)
        Actual: \(actualState)
        Context: \(context)
        """
        
        generalLog.error("⚠️ \(message)")
        writeToLogFile("[\(timestamp())] UNEXPECTED_STATE: \(message)\n")
    }
    
    func logPerformanceMetric(operation: String, duration: TimeInterval, threshold: TimeInterval? = nil, additionalMetrics: [String: Any] = [:]) {
        let isSlowOperation = if let threshold = threshold { duration > threshold } else { false }
        let status = isSlowOperation ? "🐌" : "⚡"
        
        let message = """
        [PERFORMANCE \(status)]
        Operation: \(operation)
        Duration: \(String(format: "%.3f", duration))s
        Threshold: \(threshold.map { String(format: "%.3f", $0) + "s" } ?? "N/A")
        Additional Metrics: \(additionalMetrics)
        """
        
        if isSlowOperation {
            generalLog.error("\(message)")
        } else {
            generalLog.debug("\(message)")
        }
        
        writeToLogFile("[\(timestamp())] PERF: \(message)\n")
    }
}