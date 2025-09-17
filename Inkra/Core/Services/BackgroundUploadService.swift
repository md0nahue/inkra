import Foundation
#if canImport(UIKit)
import UIKit
#endif

protocol BackgroundUploadServiceProtocol {
    func uploadAudio(data: Data, to uploadURL: String, for questionId: Int) async throws
    func setDelegate(_ delegate: BackgroundUploadDelegate)
}

@MainActor
protocol BackgroundUploadDelegate: AnyObject {
    func uploadDidComplete(for questionId: Int, success: Bool, error: Error?)
    func uploadDidProgress(for questionId: Int, progress: Double)
}

class BackgroundUploadService: NSObject, BackgroundUploadServiceProtocol {
    static let shared = BackgroundUploadService()
    
    private let backgroundIdentifier = "com.inkra.background-upload"
    private lazy var backgroundSession: URLSession = {
        let config = URLSessionConfiguration.background(withIdentifier: backgroundIdentifier)
        config.sessionSendsLaunchEvents = true
        config.isDiscretionary = false
        config.allowsCellularAccess = true
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 300 // 5 minutes
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()
    
    private var activeUploads: [Int: String] = [:] // questionId -> taskIdentifier
    private var uploadData: [String: Data] = [:] // taskIdentifier -> data
    private var questionIdMap: [String: Int] = [:] // taskIdentifier -> questionId
    private var uploadURLs: [Int: String] = [:] // questionId -> uploadURL
    private var retryAttempts: [Int: Int] = [:] // questionId -> retry count
    private var retryTimers: [Int: Timer] = [:] // questionId -> retry timer
    private var temporaryFiles: [String: URL] = [:] // taskIdentifier -> temp file URL
    
    weak var delegate: BackgroundUploadDelegate?
    
    private override init() {
        super.init()
    }
    
    func setDelegate(_ delegate: BackgroundUploadDelegate) {
        self.delegate = delegate
    }
    
    func uploadAudio(data: Data, to uploadURL: String, for questionId: Int) async throws {
        guard let url = URL(string: uploadURL) else {
            throw NetworkError.invalidURL
        }
        
        // Cancel any existing upload and retry timer for this question
        cancelExistingUpload(for: questionId)
        
        // Store for retry purposes
        uploadURLs[questionId] = uploadURL
        retryAttempts[questionId] = 0
        
        try startUpload(data: data, url: url, for: questionId)
    }
    
    private func startUpload(data: Data, url: URL, for questionId: Int) throws {
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("audio/m4a", forHTTPHeaderField: "Content-Type")
        
        // Write data to temporary file (required for background sessions)
        let tempDirectory = FileManager.default.temporaryDirectory
        let tempFileName = "inkra_upload_\(questionId)_\(UUID().uuidString).m4a"
        let tempFileURL = tempDirectory.appendingPathComponent(tempFileName)
        
        try data.write(to: tempFileURL)
        
        // Create upload task from file (required for background sessions)
        let uploadTask = backgroundSession.uploadTask(with: request, fromFile: tempFileURL)
        let taskIdentifier = "\(uploadTask.taskIdentifier)"
        
        // Store mappings
        activeUploads[questionId] = taskIdentifier
        uploadData[taskIdentifier] = data
        questionIdMap[taskIdentifier] = questionId
        temporaryFiles[taskIdentifier] = tempFileURL
        uploadTask.taskDescription = taskIdentifier
        
        // Start the upload
        uploadTask.resume()
        
        let attempt = retryAttempts[questionId] ?? 0
        print("🚀 Started background upload for question \(questionId) (attempt \(attempt + 1)) with task ID: \(taskIdentifier)")
    }
    
    private func cancelExistingUpload(for questionId: Int) {
        // Cancel any existing upload task
        if let existingTaskId = activeUploads[questionId] {
            backgroundSession.getAllTasks { tasks in
                for task in tasks {
                    if task.taskDescription == existingTaskId {
                        task.cancel()
                        break
                    }
                }
            }
        }
        
        // Cancel any retry timer
        retryTimers[questionId]?.invalidate()
        retryTimers.removeValue(forKey: questionId)
    }
    
    private func cleanupTaskData(taskIdentifier: String) {
        if let questionId = questionIdMap[taskIdentifier] {
            activeUploads.removeValue(forKey: questionId)
        }
        
        // Clean up temporary file
        if let tempFileURL = temporaryFiles[taskIdentifier] {
            try? FileManager.default.removeItem(at: tempFileURL)
            temporaryFiles.removeValue(forKey: taskIdentifier)
        }
        
        uploadData.removeValue(forKey: taskIdentifier)
        questionIdMap.removeValue(forKey: taskIdentifier)
    }
    
    private func cleanupQuestionData(for questionId: Int) {
        uploadURLs.removeValue(forKey: questionId)
        retryAttempts.removeValue(forKey: questionId)
        retryTimers[questionId]?.invalidate()
        retryTimers.removeValue(forKey: questionId)
    }
    
    private func shouldRetry(error: Error) -> Bool {
        if let networkError = error as? NetworkError {
            switch networkError {
            case .serverError(let code):
                // Retry on temporary server errors (5xx) and some 4xx errors
                return code >= 500 || code == 408 || code == 429
            case .timeout, .networkUnavailable:
                return true
            default:
                return false
            }
        }
        
        // Retry on URLSession errors that might be temporary
        let nsError = error as NSError
        switch nsError.code {
        case NSURLErrorTimedOut,
             NSURLErrorCannotConnectToHost,
             NSURLErrorNetworkConnectionLost,
             NSURLErrorNotConnectedToInternet,
             NSURLErrorDNSLookupFailed:
            return true
        default:
            return false
        }
    }
    
    private func retryUpload(for questionId: Int) {
        guard let uploadURL = uploadURLs[questionId],
              let url = URL(string: uploadURL) else {
            print("❌ Cannot retry upload for question \(questionId): missing URL")
            DispatchQueue.main.async {
                self.delegate?.uploadDidComplete(for: questionId, success: false, error: NetworkError.invalidURL)
            }
            cleanupQuestionData(for: questionId)
            return
        }
        
        let currentAttempts = retryAttempts[questionId] ?? 0
        let maxRetries = 3
        
        if currentAttempts >= maxRetries {
            print("❌ Max retries exceeded for question \(questionId)")
            DispatchQueue.main.async {
                self.delegate?.uploadDidComplete(for: questionId, success: false, error: NetworkError.unknown(NSError(domain: "BackgroundUpload", code: -1, userInfo: [NSLocalizedDescriptionKey: "Max retries exceeded"])))
            }
            cleanupQuestionData(for: questionId)
            return
        }
        
        // Exponential backoff: 2^attempt seconds (2, 4, 8 seconds)
        let delay = TimeInterval(pow(2.0, Double(currentAttempts)))
        print("⏱️ Retrying upload for question \(questionId) in \(delay) seconds (attempt \(currentAttempts + 1))")
        
        retryAttempts[questionId] = currentAttempts + 1
        
        let timer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            
            // Find the original data for this question
            if let taskId = self.activeUploads.values.first(where: { taskId in
                self.questionIdMap[taskId] == questionId
            }),
               let data = self.uploadData[taskId] {
                
                do {
                    try self.startUpload(data: data, url: url, for: questionId)
                } catch {
                    print("❌ Failed to start retry upload for question \(questionId): \(error)")
                    DispatchQueue.main.async {
                        self.delegate?.uploadDidComplete(for: questionId, success: false, error: error)
                    }
                    self.cleanupQuestionData(for: questionId)
                }
            } else {
                print("❌ Cannot retry upload for question \(questionId): missing data")
                DispatchQueue.main.async {
                    self.delegate?.uploadDidComplete(for: questionId, success: false, error: NetworkError.noData)
                }
                self.cleanupQuestionData(for: questionId)
            }
        }
        
        retryTimers[questionId] = timer
    }
    
    // Handle app launch from background upload completion
    func handleBackgroundURLSession(identifier: String, completionHandler: @escaping () -> Void) {
        guard identifier == backgroundIdentifier else {
            completionHandler()
            return
        }
        
        // Store completion handler to call when all background tasks are done
        DispatchQueue.main.async {
            completionHandler()
        }
    }
}

// MARK: - URLSessionDelegate
@available(iOS 15.0, macOS 11.0, *)
extension BackgroundUploadService: URLSessionDelegate {
    func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
        print("❌ Background session became invalid: \(error?.localizedDescription ?? "Unknown error")")
    }
    
    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        print("✅ Background session finished all events")
        
        DispatchQueue.main.async {
            // Notify app delegate that background processing is complete
            #if canImport(UIKit)
            if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
                appDelegate.backgroundSessionCompletionHandler?()
                appDelegate.backgroundSessionCompletionHandler = nil
            }
            #endif
        }
    }
}

// MARK: - URLSessionTaskDelegate
@available(iOS 15.0, macOS 11.0, *)
extension BackgroundUploadService: URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let taskIdentifier = task.taskDescription else { return }
        
        let questionId = questionIdMap[taskIdentifier] ?? -1
        
        if let error = error {
            print("❌ Upload failed for question \(questionId): \(error.localizedDescription)")
            
            cleanupTaskData(taskIdentifier: taskIdentifier)
            
            // Check if we should retry
            if shouldRetry(error: error) {
                retryUpload(for: questionId)
            } else {
                cleanupQuestionData(for: questionId)
                DispatchQueue.main.async {
                    self.delegate?.uploadDidComplete(for: questionId, success: false, error: error)
                }
            }
        } else if let httpResponse = task.response as? HTTPURLResponse {
            let success = (200...299).contains(httpResponse.statusCode)
            
            cleanupTaskData(taskIdentifier: taskIdentifier)
            
            if success {
                print("✅ Upload completed successfully for question \(questionId)")
                cleanupQuestionData(for: questionId)
                DispatchQueue.main.async {
                    self.delegate?.uploadDidComplete(for: questionId, success: true, error: nil)
                }
            } else {
                print("❌ Upload failed for question \(questionId) with status: \(httpResponse.statusCode)")
                
                let serverError = NetworkError.serverError(httpResponse.statusCode)
                
                // Check if we should retry
                if shouldRetry(error: serverError) {
                    retryUpload(for: questionId)
                } else {
                    cleanupQuestionData(for: questionId)
                    DispatchQueue.main.async {
                        self.delegate?.uploadDidComplete(for: questionId, success: false, error: serverError)
                    }
                }
            }
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        guard let taskIdentifier = task.taskDescription,
              let questionId = questionIdMap[taskIdentifier] else { return }
        
        let progress = Double(totalBytesSent) / Double(totalBytesExpectedToSend)
        
        DispatchQueue.main.async {
            self.delegate?.uploadDidProgress(for: questionId, progress: progress)
        }
    }
}

// MARK: - UIKit Integration Check
#if canImport(UIKit)
import UIKit
#endif