import SwiftUI
import Foundation

@available(iOS 15.0, macOS 11.0, *)
struct PodcastStatusView: View {
    let projectId: Int
    let jobId: String
    @Binding var progress: Int
    let onComplete: (URL) -> Void
    let onError: (String) -> Void
    
    @State private var status: String = "pending"
    @State private var currentStep: String = "Preparing audio segments"
    @State private var isPolling = false
    @Environment(\.dismiss) private var dismiss
    
    private let exportService = LocalExportService()
    private let pollInterval: TimeInterval = 3.0
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: statusIcon)
                        .font(.system(size: 50))
                        .foregroundColor(statusColor)
                    
                    Text("Podcast Export")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text(statusMessage)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(16)
                
                // Progress Section
                if status != "completed" && status != "failed" {
                    VStack(spacing: 16) {
                        ProgressView(value: Double(progress), total: 100)
                            .progressViewStyle(LinearProgressViewStyle())
                            .scaleEffect(1.2)
                        
                        Text("\(progress)% Complete")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Text(currentStep)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.05), radius: 2)
                }
                
                // Status Details
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Status:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(status.capitalized)
                            .font(.caption)
                            .fontWeight(.medium)
                        
                        Spacer()
                    }
                    
                    HStack {
                        Text("Job ID:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if #available(iOS 16.1, *) {
                            Text(jobId)
                                .font(.caption)
                                .fontDesign(.monospaced)
                        } else {
                            Text(jobId)
                                .font(.caption)
                                .font(.system(.caption, design: .monospaced))
                        }
                        
                        Spacer()
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
                
                Spacer()
                
                // Action Buttons
                HStack(spacing: 16) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                    
                    if status == "failed" {
                        Button("Retry") {
                            startPolling()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
            .padding()
            .navigationTitle("Export Progress")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .onAppear {
                startPolling()
            }
            .onDisappear {
                isPolling = false
            }
        }
    }
    
    private var statusIcon: String {
        switch status {
        case "completed":
            return "checkmark.circle.fill"
        case "failed":
            return "xmark.circle.fill"
        case "processing", "working":
            return "gearshape.2.fill"
        default:
            return "clock.fill"
        }
    }
    
    private var statusColor: Color {
        switch status {
        case "completed":
            return .green
        case "failed":
            return .red
        case "processing", "working":
            return .blue
        default:
            return .orange
        }
    }
    
    private var statusMessage: String {
        switch status {
        case "completed":
            return "Your podcast has been successfully created and is ready for download!"
        case "failed":
            return "There was an error creating your podcast. Please try again."
        case "processing", "working":
            return "We're stitching together your audio segments. This may take a few minutes."
        default:
            return "Your podcast export has been queued and will begin processing shortly."
        }
    }
    
    private func startPolling() {
        guard !isPolling else { return }
        isPolling = true
        
        Task {
            while isPolling {
                do {
                    let statusResponse = try await exportService.checkPodcastStatus(
                        projectId: projectId,
                        jobId: jobId
                    )
                    
                    await MainActor.run {
                        status = statusResponse.status
                        progress = statusResponse.progress ?? 0
                        currentStep = statusResponse.currentStep ?? "Processing..."
                        
                        switch statusResponse.status {
                        case "completed":
                            isPolling = false
                            if let downloadUrl = statusResponse.downloadUrl,
                               let url = URL(string: downloadUrl) {
                                // Download the file
                                downloadPodcastFile(from: url, filename: statusResponse.filename)
                            } else {
                                onError("Download URL not available")
                            }
                            
                        case "failed":
                            isPolling = false
                            let errorMsg = statusResponse.error ?? "Unknown error occurred during podcast creation"
                            onError(errorMsg)
                            
                        case "not_found":
                            isPolling = false
                            onError("Export job not found or has expired")
                            
                        default:
                            // Continue polling for pending/processing states
                            break
                        }
                    }
                } catch {
                    await MainActor.run {
                        isPolling = false
                        onError("Failed to check export status: \(error.localizedDescription)")
                    }
                    break
                }
                
                if isPolling {
                    try? await Task.sleep(nanoseconds: UInt64(pollInterval * 1_000_000_000))
                }
            }
        }
    }
    
    private func downloadPodcastFile(from url: URL, filename: String?) {
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                
                // Create temporary file
                let tempDir = FileManager.default.temporaryDirectory
                let fileName = filename ?? "podcast_export.mp3"
                let fileURL = tempDir.appendingPathComponent(fileName)
                
                try data.write(to: fileURL)
                
                await MainActor.run {
                    onComplete(fileURL)
                }
            } catch {
                await MainActor.run {
                    onError("Failed to download podcast file: \(error.localizedDescription)")
                }
            }
        }
    }
}

#if DEBUG
struct PodcastStatusView_Previews: PreviewProvider {
    static var previews: some View {
        PodcastStatusView(
            projectId: 1,
            jobId: "test-job-123",
            progress: .constant(45),
            onComplete: { _ in },
            onError: { _ in }
        )
    }
}
#endif