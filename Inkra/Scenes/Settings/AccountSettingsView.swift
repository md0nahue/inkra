import SwiftUI

struct AccountSettingsView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var lifecycleService = UserLifecycleService.shared
    @State private var showingDeleteForm = false
    @State private var showingExportForm = false
    @State private var deleteReason = ""
    @State private var isDeleting = false
    @State private var deleteError: String?
    
    var body: some View {
        NavigationView {
            Form {
                SwiftUI.Section(header: Text("Account Information")) {
                    HStack {
                        Text("Email")
                        Spacer()
                        Text("V1 User")
                            .foregroundColor(.secondary)
                    }
                }
                
                // Data Export section
                SwiftUI.Section(
                    header: Text("Data Export"),
                    footer: Text("Request a complete export of all your interview data, including audio recordings and transcripts.")
                        .foregroundColor(.secondary)
                ) {
                    Button(action: {
                        showingExportForm = true
                    }) {
                        HStack {
                            Image(systemName: "square.and.arrow.down")
                            Text("Export My Data")
                        }
                        .foregroundColor(.blue)
                    }
                    .disabled(lifecycleService.isExportInProgress)
                    
                    if let status = lifecycleService.exportStatus {
                        HStack {
                            Image(systemName: "info.circle")
                            Text(status)
                        }
                        .foregroundColor(.secondary)
                        .font(.caption)
                    }
                }
                
                // Interests section removed - using custom topics only
                
                // Diagnostics section for staging/debug builds
                if AppConfig.shouldShowDiagnostics {
                    SwiftUI.Section(header: Text("Developer Tools")) {
                        NavigationLink(destination: DiagnosticsView()) {
                            HStack {
                                Image(systemName: "wrench.and.screwdriver")
                                Text("Diagnostics & Logs")
                            }
                        }
                    }
                }
                
                SwiftUI.Section(
                    header: Text("Danger Zone"),
                    footer: Text("This action cannot be undone. All your data will be permanently deleted.")
                        .foregroundColor(.secondary)
                ) {
                    Button(action: {
                        showingDeleteForm = true
                    }) {
                        HStack {
                            Image(systemName: "trash")
                            Text("Delete Account")
                        }
                        .foregroundColor(.red)
                    }
                    .disabled(isDeleting)
                }
            }
            .navigationTitle("Account Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingExportForm) {
                DataExportView(
                    onExport: {
                        await performDataExport()
                    },
                    onCancel: {
                        showingExportForm = false
                    }
                )
            }
            .sheet(isPresented: $showingDeleteForm) {
                EnhancedDeleteAccountView(
                    isDeleting: $isDeleting,
                    onDelete: { experienceDescription, whatWouldChange, requestExport in
                        await performEnhancedDeleteAccount(
                            experienceDescription: experienceDescription,
                            whatWouldChange: whatWouldChange,
                            requestExport: requestExport
                        )
                    },
                    onCancel: {
                        showingDeleteForm = false
                    }
                )
            }
        }
    }
    
    private func performDataExport() async {
        do {
            let _ = try await lifecycleService.requestDataExport()
            showingExportForm = false
            
            // Auto-refresh status after requesting export
            try? await refreshExportStatus()
        } catch {
            print("Export failed: \(error)")
            // Error is shown in the UI via lifecycleService.exportStatus
        }
    }
    
    private func refreshExportStatus() async throws {
        let _ = try await lifecycleService.checkExportStatus()
    }
    
    private func performEnhancedDeleteAccount(
        experienceDescription: String,
        whatWouldChange: String?,
        requestExport: Bool
    ) async {
        isDeleting = true
        
        do {
            let _ = try await lifecycleService.deleteAccount(
                experienceDescription: experienceDescription,
                whatWouldChange: whatWouldChange,
                requestExport: requestExport
            )
            
            // Clear auth after successful deletion request
            // Auth disabled in V1 - no logout needed
            dismiss()
        } catch {
            deleteError = error.localizedDescription
            isDeleting = false
        }
    }
    
    // Keep legacy method for compatibility
    private func performDeleteAccount(reason: String) async {
        await performEnhancedDeleteAccount(
            experienceDescription: reason,
            whatWouldChange: nil,
            requestExport: false
        )
    }
}

struct DeleteAccountView: View {
    @Binding var isDeleting: Bool
    let onDelete: (String) async -> Void
    let onCancel: () -> Void
    
    @State private var deleteReason = ""
    @State private var showingConfirmation = false
    
    var isValidReason: Bool {
        deleteReason.count >= 20
    }
    
    var body: some View {
        NavigationView {
            Form {
                SwiftUI.Section(
                    header: Text("Deletion Reason"),
                    footer: Text("Minimum 20 characters required")
                ) {
                    Text("Please provide a reason for deleting your account. This helps us improve our service.")
                        .foregroundColor(.secondary)
                    
                    TextField("Enter your reason here...", text: $deleteReason)
                        .disabled(isDeleting)
                    
                    HStack {
                        Text("Characters: \(deleteReason.count)/20")
                            .font(.caption)
                            .foregroundColor(isValidReason ? .green : .orange)
                        Spacer()
                    }
                }
                
                SwiftUI.Section(footer: Text("This action cannot be undone. All your data will be permanently deleted.").foregroundColor(.red)) {
                    Button("Delete Account") {
                        showingConfirmation = true
                    }
                    .foregroundColor(.red)
                    .disabled(!isValidReason || isDeleting)
                }
            }
            .navigationTitle("Delete Account")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(leading:
                Button("Cancel") {
                    onCancel()
                }
                .disabled(isDeleting)
            )
            .alert("Confirm Deletion", isPresented: $showingConfirmation) {
                Button("Delete", role: .destructive) {
                    Task {
                        await onDelete(deleteReason)
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Are you sure you want to delete your account? This action cannot be undone.")
            }
        }
    }
}

// MARK: - Data Export View

struct DataExportView: View {
    let onExport: () async -> Void
    let onCancel: () -> Void
    
    @StateObject private var lifecycleService = UserLifecycleService.shared
    @State private var exportStatus: ExportStatusResponse?
    @State private var isRefreshing = false
    
    var body: some View {
        NavigationView {
            Form {
                if let status = exportStatus {
                    exportStatusSection(status)
                } else {
                    noExportSection
                }
                
                whatIncludedSection
                
                actionSection
            }
            .navigationTitle("Export Data")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    onCancel()
                }.disabled(lifecycleService.isExportInProgress),
                trailing: Button("Refresh") {
                    Task {
                        await refreshStatus()
                    }
                }.disabled(isRefreshing)
            )
            .onAppear {
                Task {
                    await refreshStatus()
                }
            }
        }
    }
    
    @ViewBuilder
    private func exportStatusSection(_ status: ExportStatusResponse) -> some View {
        if status.hasExport {
            SwiftUI.Section(
                header: Text("Current Export"),
                footer: Text("You can only request one export per week to prevent abuse.")
            ) {
                HStack {
                    Text("Status")
                    Spacer()
                    Text(status.status?.capitalized ?? "Unknown")
                        .foregroundColor(statusColor(status.status))
                }
                
                if let fileCount = status.fileCount, let fileSize = status.fileSize {
                    HStack {
                        Text("Files")
                        Spacer()
                        Text("\(fileCount) files (\(fileSize))")
                            .foregroundColor(.secondary)
                    }
                }
                
                if let createdAt = status.createdAt {
                    HStack {
                        Text("Created")
                        Spacer()
                        Text(createdAt, style: .relative)
                            .foregroundColor(.secondary)
                    }
                }
                
                if let daysUntilExpiration = status.daysUntilExpiration, daysUntilExpiration > 0 {
                    HStack {
                        Text("Expires")
                        Spacer()
                        Text("In \(daysUntilExpiration) days")
                            .foregroundColor(.orange)
                    }
                }
                
                if status.dataIsStale == true {
                    HStack {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundColor(.orange)
                        Text("Data has changed since export")
                            .foregroundColor(.orange)
                    }
                    .font(.caption)
                }
                
                // Download and Share buttons
                if let downloadUrl = status.downloadUrl {
                    VStack(spacing: 12) {
                        Button(action: {
                            if let url = URL(string: downloadUrl) {
                                UIApplication.shared.open(url)
                            }
                        }) {
                            HStack {
                                Image(systemName: "square.and.arrow.down")
                                Text("Download Export")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                        
                        if let shareUrl = status.shareUrl {
                            Button(action: {
                                if let url = URL(string: shareUrl) {
                                    UIApplication.shared.open(url)
                                }
                            }) {
                                HStack {
                                    Image(systemName: "envelope")
                                    Text("Share via Email")
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.green)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                            }
                        }
                        
                        Button(action: {
                            if let downloadUrl = status.downloadUrl {
                                UIPasteboard.general.string = downloadUrl
                            }
                        }) {
                            HStack {
                                Image(systemName: "doc.on.doc")
                                Text("Copy Link")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.gray)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private var noExportSection: some View {
        SwiftUI.Section(
            header: Text("No Export Found"),
            footer: Text("Create your first data export to download all your Inkra data.")
        ) {
            Text("You haven't created any data exports yet.")
                .foregroundColor(.secondary)
        }
    }
    
    @ViewBuilder
    private var whatIncludedSection: some View {
        SwiftUI.Section(
            header: Text("What's Included"),
            footer: Text("All data is exported in standard formats (CSV, audio files) that you can use with any application.")
        ) {
            Label("Interview projects and metadata", systemImage: "folder")
            Label("All audio recordings", systemImage: "waveform")
            Label("Text transcripts", systemImage: "doc.text")
            Label("Account settings and preferences", systemImage: "person.circle")
            Label("Support history and feedback", systemImage: "bubble.left")
        }
    }
    
    @ViewBuilder
    private var actionSection: some View {
        SwiftUI.Section {
            if let status = exportStatus, !status.canCreateNew {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Export Limit Reached")
                        .font(.headline)
                        .foregroundColor(.orange)
                    
                    if let daysUntilNext = status.daysUntilNextExport {
                        Text("You can create a new export in \(daysUntilNext) days")
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
            } else {
                Button("Create New Export") {
                    Task {
                        await onExport()
                    }
                }
                .disabled(lifecycleService.isExportInProgress || isRefreshing)
                
                if lifecycleService.isExportInProgress {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Creating export...")
                    }
                }
            }
        }
    }
    
    private func statusColor(_ status: String?) -> Color {
        switch status?.lowercased() {
        case "completed":
            return .green
        case "processing":
            return .blue
        case "failed":
            return .red
        case "expired":
            return .orange
        default:
            return .secondary
        }
    }
    
    private func refreshStatus() async {
        isRefreshing = true
        defer { isRefreshing = false }
        
        do {
            let status = try await lifecycleService.checkExportStatus()
            await MainActor.run {
                self.exportStatus = status
            }
        } catch {
            print("Failed to refresh export status: \(error)")
        }
    }
}

// MARK: - Enhanced Delete Account View

struct EnhancedDeleteAccountView: View {
    @Binding var isDeleting: Bool
    let onDelete: (String, String?, Bool) async -> Void
    let onCancel: () -> Void
    
    @State private var experienceDescription = ""
    @State private var whatWouldChange = ""
    @State private var requestExport = false
    @State private var showingFinalConfirmation = false
    
    var isValidDescription: Bool {
        experienceDescription.count >= 10
    }
    
    var body: some View {
        NavigationView {
            Form {
                SwiftUI.Section(
                    header: Text("Tell us about your experience"),
                    footer: Text("Minimum 10 characters required. This feedback helps us improve Inkra.")
                ) {
                    TextEditor(text: $experienceDescription)
                        .frame(minHeight: 100)
                        .disabled(isDeleting)
                    
                    HStack {
                        Text("Characters: \(experienceDescription.count)/10")
                            .font(.caption)
                            .foregroundColor(isValidDescription ? .green : .orange)
                        Spacer()
                    }
                }
                
                SwiftUI.Section(
                    header: Text("What would you change?"),
                    footer: Text("Optional - help us understand what could be better.")
                ) {
                    TextEditor(text: $whatWouldChange)
                        .frame(minHeight: 80)
                        .disabled(isDeleting)
                }
                
                SwiftUI.Section(
                    header: Text("Data Export"),
                    footer: Text("Get a complete copy of your data before deletion. This will be emailed to you before your account is deleted.")
                ) {
                    Toggle("Send me my data export", isOn: $requestExport)
                        .disabled(isDeleting)
                }
                
                SwiftUI.Section(
                    footer: Text("This action cannot be undone. All your interview data, recordings, and account information will be permanently deleted.")
                        .foregroundColor(.red)
                ) {
                    Button("Delete My Account") {
                        showingFinalConfirmation = true
                    }
                    .foregroundColor(.red)
                    .disabled(!isValidDescription || isDeleting)
                    
                    if isDeleting {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Processing deletion...")
                        }
                    }
                }
            }
            .navigationTitle("Delete Account")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(leading:
                Button("Cancel") {
                    onCancel()
                }
                .disabled(isDeleting)
            )
            .alert("Final Confirmation", isPresented: $showingFinalConfirmation) {
                Button("Delete Account", role: .destructive) {
                    Task {
                        await onDelete(
                            experienceDescription,
                            whatWouldChange.isEmpty ? nil : whatWouldChange,
                            requestExport
                        )
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                if requestExport {
                    Text("Your data export will be sent to your email first, then your account will be deleted in 30 minutes. This cannot be undone.")
                } else {
                    Text("Your account and all data will be permanently deleted immediately. This cannot be undone.")
                }
            }
        }
    }
}

#Preview {
    AccountSettingsView()
}