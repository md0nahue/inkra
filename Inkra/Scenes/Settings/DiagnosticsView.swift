import SwiftUI

struct DiagnosticsView: View {
    @State private var isUploading = false
    @State private var uploadStatus: String = ""
    @State private var logFiles: [URL] = []
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var selectedLogType = LogUploader.LogType.manual
    
    var body: some View {
        NavigationView {
            Form {
                SwiftUI.Section(header: Text("Device Information")) {
                    HStack {
                        Text("Device")
                        Spacer()
                        Text(UIDevice.current.modelName)
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("iOS Version")
                        Spacer()
                        Text(UIDevice.current.systemVersion)
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("App Version")
                        Spacer()
                        Text(appVersion)
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Build Number")
                        Spacer()
                        Text(buildNumber)
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Device ID")
                        Spacer()
                        Text(deviceId)
                            .foregroundColor(.secondary)
                    }
                }
                
                SwiftUI.Section(header: Text("Log Files")) {
                    if logFiles.isEmpty {
                        Text("No log files found")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(logFiles, id: \.self) { file in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(file.lastPathComponent)
                                        .font(.caption)
                                    Text(formattedFileSize(for: file))
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                if file == LogManager.shared.getCurrentLogFileURL() {
                                    Text("Current")
                                        .font(.caption2)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 2)
                                        .background(Color.blue.opacity(0.2))
                                        .cornerRadius(4)
                                }
                            }
                        }
                    }
                    
                    Button(action: refreshLogFiles) {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                }
                
                SwiftUI.Section(header: Text("Upload Options")) {
                    Picker("Log Type", selection: $selectedLogType) {
                        Text("Manual").tag(LogUploader.LogType.manual)
                        Text("Debug").tag(LogUploader.LogType.debug)
                        Text("Automatic").tag(LogUploader.LogType.automatic)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                SwiftUI.Section(header: Text("Actions")) {
                    Button(action: uploadCurrentLog) {
                        HStack {
                            Image(systemName: "icloud.and.arrow.up")
                            Text("Upload Current Log")
                        }
                    }
                    .disabled(isUploading)
                    
                    Button(action: uploadAllLogs) {
                        HStack {
                            Image(systemName: "icloud.and.arrow.up.fill")
                            Text("Upload All Logs")
                        }
                    }
                    .disabled(isUploading || logFiles.isEmpty)
                    
                    Button(action: clearAllLogs) {
                        HStack {
                            Image(systemName: "trash")
                            Text("Clear All Logs")
                        }
                        .foregroundColor(.red)
                    }
                    .disabled(isUploading || logFiles.isEmpty)
                    
                    Button(action: triggerTestCrash) {
                        HStack {
                            Image(systemName: "exclamationmark.triangle")
                            Text("Test Crash (Debug Only)")
                        }
                        .foregroundColor(.orange)
                    }
                    #if !DEBUG
                    .hidden()
                    #endif
                }
                
                if !uploadStatus.isEmpty {
                    SwiftUI.Section(header: Text("Status")) {
                        Text(uploadStatus)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Diagnostics")
            .navigationBarTitleDisplayMode(.large)
            .navigationBarItems(
                trailing: isUploading ? AnyView(ProgressView()) : AnyView(EmptyView())
            )
            .alert("Diagnostics", isPresented: $showingAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(alertMessage)
            }
        }
        .onAppear {
            refreshLogFiles()
            // Log that diagnostics view was opened
            LogManager.shared.info("Diagnostics view opened")
        }
    }
    
    // MARK: - Computed Properties
    
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }
    
    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
    }
    
    private var deviceId: String {
        UIDevice.current.identifierForVendor?.uuidString ?? "Unknown"
    }
    
    // MARK: - Actions
    
    private func refreshLogFiles() {
        logFiles = LogManager.shared.getAllLogFiles()
            .sorted { file1, file2 in
                let date1 = (try? file1.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
                let date2 = (try? file2.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
                return date1 > date2
            }
    }
    
    private func uploadCurrentLog() {
        isUploading = true
        uploadStatus = "Uploading current log..."
        
        Task {
            let success = await LogUploader.shared.uploadCurrentLog(logType: selectedLogType)
            
            await MainActor.run {
                isUploading = false
                if success {
                    uploadStatus = "Current log uploaded successfully"
                    alertMessage = "Log file uploaded successfully to server"
                } else {
                    uploadStatus = "Failed to upload current log"
                    alertMessage = "Failed to upload log file. Please check your connection and try again."
                }
                showingAlert = true
                refreshLogFiles()
            }
        }
    }
    
    private func uploadAllLogs() {
        isUploading = true
        uploadStatus = "Uploading all logs..."
        
        Task {
            await LogUploader.shared.uploadAllLogs(logType: selectedLogType)
            
            await MainActor.run {
                isUploading = false
                uploadStatus = "All logs uploaded"
                alertMessage = "All log files have been processed"
                showingAlert = true
                refreshLogFiles()
            }
        }
    }
    
    private func clearAllLogs() {
        LogManager.shared.clearAllLogs()
        refreshLogFiles()
        alertMessage = "All log files have been cleared"
        showingAlert = true
    }
    
    private func triggerTestCrash() {
        LogManager.shared.crash("Test crash triggered from diagnostics view")
        // Simulate a crash for testing
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            fatalError("Test crash triggered")
        }
    }
    
    private func formattedFileSize(for url: URL) -> String {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let fileSize = attributes[.size] as? Int else {
            return "Unknown size"
        }
        
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(fileSize))
    }
}

struct DiagnosticsView_Previews: PreviewProvider {
    static var previews: some View {
        DiagnosticsView()
    }
}