import Foundation
import os
import UIKit

final class LogManager {
    static let shared = LogManager()
    
    private let fileURL: URL
    private let queue = DispatchQueue(label: "com.inkra.logmanager", qos: .utility)
    private let logger = Logger(subsystem: "com.inkra.app", category: "general")
    private let maxFileSize: Int = 10 * 1024 * 1024 // 10MB
    private let maxLogFiles: Int = 5
    
    enum LogLevel: String {
        case debug = "DEBUG"
        case info = "INFO"
        case warning = "WARNING"
        case error = "ERROR"
        case crash = "CRASH"
    }
    
    private init() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let logsDirectory = documentsPath.appendingPathComponent("Logs")
        
        // Create logs directory if it doesn't exist
        try? FileManager.default.createDirectory(at: logsDirectory, withIntermediateDirectories: true)
        
        // Use timestamp in filename for rotation
        let timestamp = Date().timeIntervalSince1970
        fileURL = logsDirectory.appendingPathComponent("inkra_\(timestamp).log")
        
        // Setup crash handlers
        setupCrashHandlers()
        
        // Check for and upload any pending crash logs
        uploadPendingCrashLogs()
    }
    
    // MARK: - Public API
    
    func log(_ message: String, level: LogLevel = .info, file: String = #file, function: String = #function, line: Int = #line) {
        let fileName = URL(fileURLWithPath: file).lastPathComponent
        let entry = formatLogEntry(message: message, level: level, file: fileName, function: function, line: line)
        
        // Log to system logger for Xcode console
        switch level {
        case .debug:
            logger.debug("\(entry)")
        case .info:
            logger.info("\(entry)")
        case .warning:
            logger.warning("\(entry)")
        case .error:
            logger.error("\(entry)")
        case .crash:
            logger.critical("\(entry)")
        }
        
        // Write to file
        writeToFile(entry)
    }
    
    func debug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .debug, file: file, function: function, line: line)
    }
    
    func info(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .info, file: file, function: function, line: line)
    }
    
    func warning(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .warning, file: file, function: function, line: line)
    }
    
    func error(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .error, file: file, function: function, line: line)
    }
    
    func crash(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .crash, file: file, function: function, line: line)
    }
    
    // MARK: - File Management
    
    private func formatLogEntry(message: String, level: LogLevel, file: String, function: String, line: Int) -> String {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let deviceInfo = getDeviceInfo()
        return "[\(timestamp)] [\(level.rawValue)] [\(file):\(line)] [\(function)] \(deviceInfo) - \(message)"
    }
    
    private func writeToFile(_ entry: String) {
        queue.async { [weak self] in
            guard let self = self else { return }
            
            let data = (entry + "\n").data(using: .utf8) ?? Data()
            
            if FileManager.default.fileExists(atPath: self.fileURL.path) {
                // Check file size and rotate if needed
                if let attributes = try? FileManager.default.attributesOfItem(atPath: self.fileURL.path),
                   let fileSize = attributes[.size] as? Int,
                   fileSize > self.maxFileSize {
                    self.rotateLogFiles()
                }
                
                // Append to existing file
                if let handle = try? FileHandle(forWritingTo: self.fileURL) {
                    handle.seekToEndOfFile()
                    handle.write(data)
                    handle.closeFile()
                }
            } else {
                // Create new file
                try? data.write(to: self.fileURL)
            }
        }
    }
    
    private func rotateLogFiles() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let logsDirectory = documentsPath.appendingPathComponent("Logs")
        
        // Get all log files sorted by creation date
        let logFiles = (try? FileManager.default.contentsOfDirectory(at: logsDirectory, includingPropertiesForKeys: [.creationDateKey]))?.filter { $0.pathExtension == "log" } ?? []
        
        // Delete old files if we exceed max count
        if logFiles.count >= maxLogFiles {
            let sortedFiles = logFiles.sorted { file1, file2 in
                let date1 = (try? file1.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
                let date2 = (try? file2.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
                return date1 < date2
            }
            
            // Delete oldest files
            for i in 0..<(sortedFiles.count - maxLogFiles + 1) {
                try? FileManager.default.removeItem(at: sortedFiles[i])
            }
        }
    }
    
    // MARK: - Device Info
    
    private func getDeviceInfo() -> String {
        let device = UIDevice.current
        let buildVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
        return "[iOS \(device.systemVersion)] [Build \(buildVersion)(\(buildNumber))] [\(device.modelName)]"
    }
    
    // MARK: - Crash Handling
    
    private func setupCrashHandlers() {
        // Handle NSException crashes
        NSSetUncaughtExceptionHandler { exception in
            LogManager.shared.crash("Uncaught Exception: \(exception.name.rawValue) - \(exception.reason ?? "No reason") - Stack: \(exception.callStackSymbols.joined(separator: "\n"))")
            LogManager.shared.markCrashLogForUpload()
        }
        
        // Handle signal crashes
        setupSignalHandlers()
    }
    
    private func setupSignalHandlers() {
        signal(SIGABRT) { signal in
            LogManager.shared.crash("Signal SIGABRT received")
            LogManager.shared.markCrashLogForUpload()
        }
        
        signal(SIGILL) { signal in
            LogManager.shared.crash("Signal SIGILL received")
            LogManager.shared.markCrashLogForUpload()
        }
        
        signal(SIGSEGV) { signal in
            LogManager.shared.crash("Signal SIGSEGV received")
            LogManager.shared.markCrashLogForUpload()
        }
        
        signal(SIGFPE) { signal in
            LogManager.shared.crash("Signal SIGFPE received")
            LogManager.shared.markCrashLogForUpload()
        }
        
        signal(SIGBUS) { signal in
            LogManager.shared.crash("Signal SIGBUS received")
            LogManager.shared.markCrashLogForUpload()
        }
        
        signal(SIGPIPE) { signal in
            LogManager.shared.crash("Signal SIGPIPE received")
            LogManager.shared.markCrashLogForUpload()
        }
    }
    
    private func markCrashLogForUpload() {
        // Mark current log file as crash log
        let crashMarkerURL = fileURL.appendingPathExtension("crash")
        try? Data().write(to: crashMarkerURL)
    }
    
    private func uploadPendingCrashLogs() {
        // This will be called on app launch to upload any crash logs
        queue.async {
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let logsDirectory = documentsPath.appendingPathComponent("Logs")
            
            // Find all crash markers
            let crashMarkers = (try? FileManager.default.contentsOfDirectory(at: logsDirectory, includingPropertiesForKeys: nil))?.filter { $0.pathExtension == "crash" } ?? []
            
            for crashMarker in crashMarkers {
                // Get corresponding log file
                let logFile = crashMarker.deletingPathExtension()
                if FileManager.default.fileExists(atPath: logFile.path) {
                    // Upload crash log
                    Task {
                        await LogUploader.shared.uploadLog(at: logFile, logType: .crash)
                    }
                }
                // Remove crash marker
                try? FileManager.default.removeItem(at: crashMarker)
            }
        }
    }
    
    // MARK: - Export Functions
    
    func getCurrentLogFileURL() -> URL {
        return fileURL
    }
    
    func getAllLogFiles() -> [URL] {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let logsDirectory = documentsPath.appendingPathComponent("Logs")
        return (try? FileManager.default.contentsOfDirectory(at: logsDirectory, includingPropertiesForKeys: [.creationDateKey]))?.filter { $0.pathExtension == "log" } ?? []
    }
    
    func clearAllLogs() {
        queue.async {
            let logFiles = self.getAllLogFiles()
            for file in logFiles {
                try? FileManager.default.removeItem(at: file)
            }
        }
    }
}

// MARK: - UIDevice Extension

extension UIDevice {
    var modelName: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        
        switch identifier {
        case "iPhone14,2": return "iPhone 13 Pro"
        case "iPhone14,3": return "iPhone 13 Pro Max"
        case "iPhone14,4": return "iPhone 13 mini"
        case "iPhone14,5": return "iPhone 13"
        case "iPhone14,6": return "iPhone SE (3rd generation)"
        case "iPhone14,7": return "iPhone 14"
        case "iPhone14,8": return "iPhone 14 Plus"
        case "iPhone15,2": return "iPhone 14 Pro"
        case "iPhone15,3": return "iPhone 14 Pro Max"
        case "iPhone15,4": return "iPhone 15"
        case "iPhone15,5": return "iPhone 15 Plus"
        case "iPhone16,1": return "iPhone 15 Pro"
        case "iPhone16,2": return "iPhone 15 Pro Max"
        case "iPhone17,1": return "iPhone 16 Pro"
        case "iPhone17,2": return "iPhone 16 Pro Max"
        case "iPhone17,3": return "iPhone 16"
        case "iPhone17,4": return "iPhone 16 Plus"
        case "i386", "x86_64", "arm64": return "Simulator"
        default: return identifier
        }
    }
}