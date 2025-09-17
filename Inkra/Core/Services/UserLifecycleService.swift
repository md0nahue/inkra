import Foundation

@available(iOS 15.0, *)
@MainActor
public class UserLifecycleService: ObservableObject {
    public static let shared = UserLifecycleService()
    
    @Published var isExportInProgress = false
    @Published var isDeletionInProgress = false
    @Published var exportStatus: String?
    @Published var deletionStatus: String?
    
    private init() {}
    
    // MARK: - Data Export
    
    func requestDataExport() async throws -> DataExportResponse {
        print("🚀 [LIFECYCLE] Requesting data export")
        
        isExportInProgress = true
        exportStatus = "Starting export..."
        
        defer {
            isExportInProgress = false
        }
        
        do {
            let request = DataExportRequest()
            let response: DataExportResponse = try await NetworkService.shared.post(
                "/api/user_lifecycle/export_user_data", 
                body: request
            )
            
            if let error = response.error {
                exportStatus = error
            } else {
                exportStatus = response.message
            }
            
            print("🚀 [LIFECYCLE] Data export request response: \(response.message)")
            
            return response
        } catch {
            exportStatus = "Export failed: \(error.localizedDescription)"
            print("🚀 [LIFECYCLE] Data export request failed: \(error)")
            throw error
        }
    }
    
    func checkExportStatus() async throws -> ExportStatusResponse {
        print("🚀 [LIFECYCLE] Checking export status...")
        
        let response: ExportStatusResponse = try await NetworkService.shared.get("/api/user_lifecycle/export_status")
        
        if let message = response.message {
            exportStatus = message
        } else if response.hasExport && response.status != nil {
            exportStatus = "Export \(response.status!)"
        }
        
        print("🚀 [LIFECYCLE] Export status: \(response.status ?? "none")")
        return response
    }
    
    // MARK: - Account Deletion
    
    func deleteAccount(
        experienceDescription: String,
        whatWouldChange: String?,
        requestExport: Bool
    ) async throws -> DeleteAccountResponse {
        print("🚀 [LIFECYCLE] Starting account deletion process...")
        print("🚀 [LIFECYCLE] Request export: \(requestExport)")
        
        guard experienceDescription.count >= 10 else {
            throw NetworkError.validationError("Experience description must be at least 10 characters")
        }
        
        isDeletionInProgress = true
        deletionStatus = "Processing deletion request..."
        
        defer {
            isDeletionInProgress = false
        }
        
        do {
            let request = DeleteAccountRequest(
                experienceDescription: experienceDescription,
                whatWouldChange: whatWouldChange,
                requestExport: requestExport
            )
            
            let response: DeleteAccountResponse = try await NetworkService.shared.post(
                "/api/user_lifecycle/delete_account",
                body: request
            )
            
            deletionStatus = response.message
            print("🚀 [LIFECYCLE] Account deletion request successful")
            print("🚀 [LIFECYCLE] Deletion scheduled: \(response.deletionScheduled)")
            print("🚀 [LIFECYCLE] Export requested: \(response.exportRequested)")
            
            return response
        } catch {
            deletionStatus = "Deletion failed: \(error.localizedDescription)"
            print("🚀 [LIFECYCLE] Account deletion failed: \(error)")
            throw error
        }
    }
    
    // MARK: - Status Management
    
    func clearStatus() {
        exportStatus = nil
        deletionStatus = nil
    }
    
    func resetState() {
        isExportInProgress = false
        isDeletionInProgress = false
        exportStatus = nil
        deletionStatus = nil
    }
}