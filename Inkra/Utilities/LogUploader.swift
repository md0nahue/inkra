import Foundation
import UIKit

final class LogUploader {
    static let shared = LogUploader()
    
    private let session = URLSession.shared
    private let queue = DispatchQueue(label: "com.inkra.loguploader", qos: .background)
    
    enum LogType: String {
        case crash = "crash"
        case manual = "manual"
        case automatic = "automatic"
        case debug = "debug"
    }
    
    private init() {}
    
    // MARK: - Public API
    
    func uploadLog(at fileURL: URL, logType: LogType) async -> Bool {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            LogManager.shared.error("Log file not found at \(fileURL.path)")
            return false
        }
        
        do {
            // Get presigned URL from backend
            guard let presignedResponse = try await getPresignedURL(logType: logType) else {
                LogManager.shared.error("Failed to get presigned URL")
                return false
            }
            
            // Upload log file to S3
            let success = try await uploadToS3(fileURL: fileURL, presignedURL: presignedResponse.uploadURL)
            
            if success {
                // Confirm upload with backend
                try await confirmUpload(logId: presignedResponse.logId)
                
                LogManager.shared.info("Successfully uploaded log file: \(fileURL.lastPathComponent)")
                
                // Delete local file after successful upload (except current log)
                if fileURL != LogManager.shared.getCurrentLogFileURL() {
                    try? FileManager.default.removeItem(at: fileURL)
                }
                
                return true
            }
            
            return false
        } catch {
            LogManager.shared.error("Log upload failed: \(error.localizedDescription)")
            return false
        }
    }
    
    func uploadAllLogs(logType: LogType = .manual) async {
        let logFiles = LogManager.shared.getAllLogFiles()
        
        LogManager.shared.info("Uploading \(logFiles.count) log files")
        
        for logFile in logFiles {
            await uploadLog(at: logFile, logType: logType)
        }
    }
    
    func uploadCurrentLog(logType: LogType = .manual) async -> Bool {
        let currentLog = LogManager.shared.getCurrentLogFileURL()
        return await uploadLog(at: currentLog, logType: logType)
    }
    
    // MARK: - Private Methods
    
    private struct PresignedURLResponse: Codable {
        let uploadURL: URL
        let logId: Int
        let s3Key: String
        let expiresAt: Date
        
        enum CodingKeys: String, CodingKey {
            case uploadURL = "upload_url"
            case logId = "log_id"
            case s3Key = "s3_key"
            case expiresAt = "expires_at"
        }
    }
    
    private func getPresignedURL(logType: LogType) async throws -> PresignedURLResponse? {
        guard let authToken = UserDefaults.standard.string(forKey: "authToken") else {
            LogManager.shared.error("No auth token available")
            return nil
        }
        
        let baseURL = AppConfig.apiBaseURL
        guard let url = URL(string: "\(baseURL)/api/device_logs/presigned_url") else {
            LogManager.shared.error("Invalid API URL")
            return nil
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let device = await UIDevice.current
        let buildVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
        
        let body: [String: Any] = [
            "device_id": await device.identifierForVendor?.uuidString ?? "unknown",
            "build_version": "\(buildVersion)(\(buildNumber))",
            "os_version": device.systemVersion,
            "log_type": logType.rawValue,
            "expires_in": 3600,
            "content_type": "text/plain"
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            LogManager.shared.error("Failed to get presigned URL: HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0)")
            return nil
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        
        return try decoder.decode(PresignedURLResponse.self, from: data)
    }
    
    private func uploadToS3(fileURL: URL, presignedURL: URL) async throws -> Bool {
        guard let logData = try? Data(contentsOf: fileURL) else {
            LogManager.shared.error("Failed to read log file")
            return false
        }
        
        var request = URLRequest(url: presignedURL)
        request.httpMethod = "PUT"
        request.setValue("text/plain", forHTTPHeaderField: "Content-Type")
        request.httpBody = logData
        
        let (_, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            LogManager.shared.error("Failed to upload to S3: HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0)")
            return false
        }
        
        return true
    }
    
    private func confirmUpload(logId: Int) async throws {
        guard let authToken = UserDefaults.standard.string(forKey: "authToken") else {
            LogManager.shared.error("No auth token available")
            return
        }
        
        let baseURL = AppConfig.apiBaseURL
        guard let url = URL(string: "\(baseURL)/api/device_logs/\(logId)/confirm_upload") else {
            LogManager.shared.error("Invalid API URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        
        let (_, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            LogManager.shared.error("Failed to confirm upload: HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0)")
            return
        }
    }
}

// MARK: - Staging Build Check

extension LogUploader {
    static var isStagingBuild: Bool {
        #if DEBUG
        return false
        #else
        // Check if this is a staging build based on build configuration
        // You can use a custom build setting or check the bundle identifier
        let bundleId = Bundle.main.bundleIdentifier ?? ""
        return bundleId.contains("staging") || bundleId.contains("beta")
        #endif
    }
}