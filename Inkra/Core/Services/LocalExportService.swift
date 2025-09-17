import Foundation
import UniformTypeIdentifiers

@available(iOS 15.0, macOS 11.0, *)
class LocalExportService {
    
    struct ExportData {
        let questions: [ChapterQuestionsWithResponses]
        let projectTitle: String
        let exportDate: Date
        
        init(questions: [ChapterQuestionsWithResponses], projectTitle: String) {
            self.questions = questions
            self.projectTitle = projectTitle
            self.exportDate = Date()
        }
    }
    
    func exportQuestionsToCSV(_ data: ExportData) -> URL? {
        var csvContent = "Question,Answer\n"
        
        for chapter in data.questions {
            for question in chapter.questions {
                let questionText = escapeCSVField(question.text)
                let answerText = escapeCSVField(question.transcribedResponse ?? "No response recorded")
                csvContent += "\"\(questionText)\",\"\(answerText)\"\n"
            }
        }
        
        return writeToTempFile(content: csvContent, fileName: generateFileName(projectTitle: data.projectTitle, extension: "csv"))
    }
    
    func exportQuestionsToTXT(_ data: ExportData) -> URL? {
        var txtContent = "\(data.projectTitle) - Questions Only\n"
        txtContent += "Generated on \(data.exportDate.formatted(date: .abbreviated, time: .shortened))\n\n"
        
        var questionNumber = 1
        for chapter in data.questions {
            txtContent += "\n=== \(chapter.chapterTitle) ===\n\n"
            
            for question in chapter.questions {
                txtContent += "Q\(questionNumber): \(question.text)\n\n"
                questionNumber += 1
            }
        }
        
        return writeToTempFile(content: txtContent, fileName: generateFileName(projectTitle: data.projectTitle, extension: "txt"))
    }
    
    // MARK: - API-based Export Methods
    
    func exportToPDF(projectId: Int, projectTitle: String) async throws -> URL {
        return try await downloadExportFile(
            projectId: projectId,
            format: "pdf",
            fileName: generateFileName(projectTitle: projectTitle, extension: "pdf")
        )
    }
    
    func exportToDOCX(projectId: Int, projectTitle: String) async throws -> URL {
        return try await downloadExportFile(
            projectId: projectId,
            format: "docx", 
            fileName: generateFileName(projectTitle: projectTitle, extension: "docx")
        )
    }
    
    func exportToCSVFromAPI(projectId: Int, projectTitle: String, includeQuestions: Bool = true) async throws -> URL {
        return try await downloadExportFile(
            projectId: projectId,
            format: "csv",
            fileName: generateFileName(projectTitle: projectTitle, extension: "csv"),
            parameters: [
                "transcript_version": "edited",
                "include_questions": includeQuestions ? "true" : "false"
            ]
        )
    }
    
    func exportToTXTFromAPI(projectId: Int, projectTitle: String, includeQuestions: Bool = true) async throws -> URL {
        return try await downloadExportFile(
            projectId: projectId,
            format: "txt",
            fileName: generateFileName(projectTitle: projectTitle, extension: "txt"),
            parameters: [
                "transcript_version": "edited",
                "include_questions": includeQuestions ? "true" : "false"
            ]
        )
    }
    
    func startPodcastExport(projectId: Int) async throws -> PodcastExportResponse {
        guard let token = await AuthService.shared.accessToken else {
            throw ExportError.notAuthenticated
        }
        
        let url = URL(string: "\(AppConfig.apiBaseURL)/api/projects/\(projectId)/export/podcast")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw ExportError.serverError
        }
        
        return try JSONDecoder().decode(PodcastExportResponse.self, from: data)
    }
    
    func checkPodcastStatus(projectId: Int, jobId: String) async throws -> PodcastStatusResponse {
        guard let token = await AuthService.shared.accessToken else {
            throw ExportError.notAuthenticated
        }
        
        let url = URL(string: "\(AppConfig.apiBaseURL)/api/projects/\(projectId)/export/podcast/status/\(jobId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw ExportError.serverError
        }
        
        return try JSONDecoder().decode(PodcastStatusResponse.self, from: data)
    }
    
    private func downloadExportFile(
        projectId: Int,
        format: String, 
        fileName: String,
        parameters: [String: String] = [:]
    ) async throws -> URL {
        guard let token = await AuthService.shared.accessToken else {
            throw ExportError.notAuthenticated
        }
        
        var urlComponents = URLComponents(string: "\(AppConfig.apiBaseURL)/api/projects/\(projectId)/export/\(format)")!
        
        if !parameters.isEmpty {
            urlComponents.queryItems = parameters.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        
        guard let url = urlComponents.url else {
            throw ExportError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw ExportError.serverError
        }
        
        // Write to temporary file
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(fileName)
        
        try data.write(to: fileURL)
        return fileURL
    }
    
    private func escapeCSVField(_ field: String) -> String {
        let cleanedField = field.replacingOccurrences(of: "\"", with: "\"\"")
        return cleanedField
    }
    
    private func generateFileName(projectTitle: String, extension: String) -> String {
        // Get first 15 characters of title, cleaned for filename use
        let titlePart = String(projectTitle.prefix(15))
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "[^a-zA-Z0-9_-]", with: "", options: .regularExpression)
        
        // Get current date
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd"
        let datePart = dateFormatter.string(from: Date())
        
        return "\(titlePart)_\(datePart).\(`extension`)"
    }
    
    private func writeToTempFile(content: String, fileName: String) -> URL? {
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(fileName)
        
        do {
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL
        } catch {
            print("Error writing export file: \(error)")
            return nil
        }
    }
}

// MARK: - Export Data Structures

enum ExportError: Error, LocalizedError {
    case notAuthenticated
    case serverError  
    case invalidURL
    case networkError
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "User is not authenticated"
        case .serverError:
            return "Server error occurred"
        case .invalidURL:
            return "Invalid export URL"
        case .networkError:
            return "Network error occurred"
        }
    }
}

struct PodcastExportResponse: Codable {
    let jobId: String
    let message: String
    let totalSegments: Int
    let estimatedDuration: String?
    
    private enum CodingKeys: String, CodingKey {
        case jobId = "job_id"
        case message
        case totalSegments = "total_segments"
        case estimatedDuration = "estimated_duration"
    }
}

struct PodcastStatusResponse: Codable {
    let status: String
    let progress: Int?
    let downloadUrl: String?
    let filename: String?
    let fileSize: String?
    let duration: String?
    let error: String?
    let currentStep: String?
    
    private enum CodingKeys: String, CodingKey {
        case status, progress, error, duration, filename
        case downloadUrl = "download_url"
        case fileSize = "file_size"
        case currentStep = "current_step"
    }
}