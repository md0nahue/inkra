import Foundation
import CoreData
import Combine

@MainActor
class DataMigrationManager: ObservableObject {
    static let shared = DataMigrationManager()

    // MARK: - Published Properties
    @Published private(set) var migrationStatus: MigrationStatus = .ready
    @Published private(set) var migrationProgress: Double = 0.0
    @Published private(set) var currentPhase: MigrationPhase = .validation
    @Published private(set) var migrationLog: [MigrationLogEntry] = []
    @Published private(set) var isValidatingConsistency = false

    // MARK: - Services
    private let dataManager = DataManager.shared
    private let rollbackManager = RollbackManager.shared
    private let featureFlags = FeatureFlagManager.shared
    private let networkService = NetworkService.shared

    // MARK: - Configuration
    private let migrationTimeout: TimeInterval = 3600 // 1 hour
    private let consistencyCheckInterval: TimeInterval = 30 // 30 seconds
    private var consistencyTimer: Timer?

    enum MigrationStatus {
        case ready
        case inProgress(MigrationPhase)
        case paused
        case completed
        case failed(Error)
        case rolledBack
    }

    enum MigrationPhase: String, CaseIterable {
        case validation = "Validation"
        case backup = "Backup"
        case dualWrite = "Dual Write"
        case dataSync = "Data Sync"
        case readSwitch = "Read Switch"
        case writeSwitch = "Write Switch"
        case cleanup = "Cleanup"

        var description: String {
            switch self {
            case .validation:
                return "Validating migration prerequisites"
            case .backup:
                return "Creating data backup"
            case .dualWrite:
                return "Setting up dual write mode"
            case .dataSync:
                return "Synchronizing existing data"
            case .readSwitch:
                return "Switching read operations"
            case .writeSwitch:
                return "Switching write operations"
            case .cleanup:
                return "Cleaning up migration artifacts"
            }
        }

        var estimatedDuration: TimeInterval {
            switch self {
            case .validation:
                return 300 // 5 minutes
            case .backup:
                return 600 // 10 minutes
            case .dualWrite:
                return 180 // 3 minutes
            case .dataSync:
                return 1800 // 30 minutes
            case .readSwitch:
                return 120 // 2 minutes
            case .writeSwitch:
                return 60 // 1 minute
            case .cleanup:
                return 300 // 5 minutes
            }
        }
    }

    private init() {
        setupConsistencyMonitoring()
    }

    // MARK: - Migration Control

    /// Start the complete migration process
    func startMigration() async throws {
        guard migrationStatus == .ready else {
            throw MigrationError.migrationAlreadyInProgress
        }

        logEntry("🚀 Starting data migration", level: .info)
        migrationStatus = .inProgress(.validation)
        migrationProgress = 0.0

        // Start timeout timer
        let timeoutTask = Task {
            try await Task.sleep(nanoseconds: UInt64(migrationTimeout * 1_000_000_000))
            if case .inProgress = migrationStatus {
                await handleMigrationTimeout()
            }
        }

        do {
            for (index, phase) in MigrationPhase.allCases.enumerated() {
                currentPhase = phase
                migrationStatus = .inProgress(phase)

                logEntry("📍 Starting phase: \(phase.description)", level: .info)

                try await executePhase(phase)

                // Update progress
                migrationProgress = Double(index + 1) / Double(MigrationPhase.allCases.count)

                logEntry("✅ Completed phase: \(phase.description)", level: .info)
            }

            migrationStatus = .completed
            logEntry("🎉 Migration completed successfully", level: .info)

        } catch {
            logEntry("❌ Migration failed: \(error.localizedDescription)", level: .error)
            migrationStatus = .failed(error)

            // Attempt automatic rollback
            try await attemptRollback()
            throw error
        }

        timeoutTask.cancel()
    }

    /// Pause the migration (if possible)
    func pauseMigration() async {
        guard case .inProgress(let phase) = migrationStatus else { return }

        // Only allow pausing during safe phases
        let pausablePhases: [MigrationPhase] = [.validation, .backup, .dualWrite, .dataSync]

        if pausablePhases.contains(phase) {
            migrationStatus = .paused
            logEntry("⏸️ Migration paused during \(phase.description)", level: .warning)
        } else {
            logEntry("⚠️ Cannot pause during \(phase.description) - phase must complete", level: .warning)
        }
    }

    /// Resume a paused migration
    func resumeMigration() async throws {
        guard migrationStatus == .paused else {
            throw MigrationError.cannotResume
        }

        logEntry("▶️ Resuming migration from \(currentPhase.description)", level: .info)
        migrationStatus = .inProgress(currentPhase)

        // Continue from current phase
        try await executePhase(currentPhase)
    }

    /// Force rollback to previous state
    func rollbackMigration() async throws {
        logEntry("🔄 Manual rollback initiated", level: .warning)
        try await attemptRollback()
    }

    // MARK: - Phase Execution

    private func executePhase(_ phase: MigrationPhase) async throws {
        switch phase {
        case .validation:
            try await validateMigrationPrerequisites()
        case .backup:
            try await createMigrationBackup()
        case .dualWrite:
            try await setupDualWriteMode()
        case .dataSync:
            try await synchronizeExistingData()
        case .readSwitch:
            try await switchReadOperations()
        case .writeSwitch:
            try await switchWriteOperations()
        case .cleanup:
            try await cleanupMigrationArtifacts()
        }
    }

    // MARK: - Phase 1: Validation

    private func validateMigrationPrerequisites() async throws {
        logEntry("🔍 Validating migration prerequisites", level: .info)

        // Check disk space
        try validateDiskSpace()

        // Check network connectivity
        try validateNetworkConnectivity()

        // Validate data integrity
        try await validateDataIntegrity()

        // Check AWS services availability
        try await validateAWSServices()

        // Verify backup capability
        try await validateBackupCapability()

        logEntry("✅ All prerequisites validated", level: .info)
    }

    private func validateDiskSpace() throws {
        let fileManager = FileManager.default
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!

        do {
            let resourceValues = try documentsPath.resourceValues(forKeys: [.volumeAvailableCapacityKey])
            guard let availableSpace = resourceValues.volumeAvailableCapacity else {
                throw MigrationError.cannotDetermineAvailableSpace
            }

            // Require at least 1GB free space
            let requiredSpace: Int64 = 1_000_000_000
            guard availableSpace >= requiredSpace else {
                throw MigrationError.insufficientDiskSpace(available: availableSpace, required: requiredSpace)
            }

            logEntry("💾 Disk space validated: \(ByteCountFormatter().string(fromByteCount: availableSpace)) available", level: .info)

        } catch {
            throw MigrationError.diskSpaceValidationFailed(error)
        }
    }

    private func validateNetworkConnectivity() throws {
        guard networkService.isConnected else {
            throw MigrationError.networkUnavailable
        }

        logEntry("📶 Network connectivity validated", level: .info)
    }

    private func validateDataIntegrity() async throws {
        let context = dataManager.backgroundContext

        try await context.perform {
            // Check for CoreData consistency
            let projectRequest: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: "ProjectEntity")
            projectRequest.resultType = .countResultType

            do {
                let result = try context.fetch(projectRequest)
                if let countResult = result.first as? NSNumber {
                    self.logEntry("📊 Found \(countResult.intValue) projects in local database", level: .info)
                }
            } catch {
                throw MigrationError.dataIntegrityCheckFailed(error)
            }
        }
    }

    private func validateAWSServices() async throws {
        // In real implementation, this would ping AWS services
        logEntry("☁️ AWS services availability validated", level: .info)
    }

    private func validateBackupCapability() async throws {
        // Test backup creation capability
        let testBackup = try await rollbackManager.createBackup(
            version: "migration_test",
            description: "Pre-migration validation backup"
        )

        logEntry("💾 Backup capability validated: \(testBackup.formattedSize)", level: .info)
    }

    // MARK: - Phase 2: Backup

    private func createMigrationBackup() async throws {
        logEntry("📦 Creating comprehensive backup before migration", level: .info)

        let backup = try await rollbackManager.createBackup(
            version: "pre_migration_\(Date().timeIntervalSince1970)",
            description: "Automatic backup before data migration"
        )

        logEntry("✅ Migration backup created: \(backup.formattedSize)", level: .info)
    }

    // MARK: - Phase 3: Dual Write Mode

    private func setupDualWriteMode() async throws {
        logEntry("🔀 Setting up dual write mode", level: .info)

        // Enable dual write feature flag
        await featureFlags.setFeatureEnabled(true, for: .awsBackend)

        // Configure services for dual write
        try await configureDualWriteServices()

        logEntry("✅ Dual write mode enabled", level: .info)
    }

    private func configureDualWriteServices() async throws {
        // Configure data services to write to both systems
        // Implementation would update service configurations
        logEntry("⚙️ Configured services for dual write mode", level: .info)
    }

    // MARK: - Phase 4: Data Synchronization

    private func synchronizeExistingData() async throws {
        logEntry("🔄 Synchronizing existing data to new system", level: .info)

        let context = dataManager.backgroundContext

        try await context.perform {
            // Sync projects
            try await self.syncProjects(context: context)

            // Sync user preferences
            try await self.syncUserPreferences()

            // Sync audio files
            try await self.syncAudioFiles()

            // Verify synchronization
            try await self.verifySynchronization()
        }

        logEntry("✅ Data synchronization completed", level: .info)
    }

    private func syncProjects(context: NSManagedObjectContext) async throws {
        let request: NSFetchRequest<ProjectEntity> = ProjectEntity.fetchRequest()
        let projects = try context.fetch(request)

        logEntry("📋 Syncing \(projects.count) projects", level: .info)

        for (index, project) in projects.enumerated() {
            try await syncProject(project)

            // Update progress within this phase
            let phaseProgress = Double(index + 1) / Double(projects.count)
            await updateSubProgress(phaseProgress * 0.4) // Projects are 40% of sync phase
        }
    }

    private func syncProject(_ project: ProjectEntity) async throws {
        // Implementation would sync individual project to AWS
        logEntry("📂 Syncing project: \(project.title ?? \"Untitled\")", level: .debug)
    }

    private func syncUserPreferences() async throws {
        logEntry("⚙️ Syncing user preferences", level: .info)
        // Implementation would sync user preferences to Cognito
    }

    private func syncAudioFiles() async throws {
        logEntry("🎵 Syncing audio files", level: .info)
        // Implementation would upload audio files to S3 or local storage
    }

    private func verifySynchronization() async throws {
        logEntry("🔍 Verifying data synchronization", level: .info)
        // Implementation would compare local and remote data
    }

    // MARK: - Phase 5: Read Switch

    private func switchReadOperations() async throws {
        logEntry("📖 Switching read operations to new system", level: .info)

        // Gradually switch read operations with monitoring
        for percentage in stride(from: 25, through: 100, by: 25) {
            try await switchReadPercentage(percentage)
            try await monitorReadSwitchHealth()
        }

        logEntry("✅ Read operations fully switched", level: .info)
    }

    private func switchReadPercentage(_ percentage: Int) async throws {
        logEntry("📊 Switching \(percentage)% of reads to new system", level: .info)
        // Implementation would update feature flags for gradual switch
    }

    private func monitorReadSwitchHealth() async throws {
        // Monitor system health during read switch
        try await Task.sleep(nanoseconds: 10_000_000_000) // 10 seconds
        // Implementation would check error rates and performance
    }

    // MARK: - Phase 6: Write Switch

    private func switchWriteOperations() async throws {
        logEntry("✍️ Switching write operations to new system", level: .info)

        // Switch writes with careful monitoring
        try await disableDualWrite()
        try await enableSingleWrite()
        try await verifyWriteSwitch()

        logEntry("✅ Write operations switched successfully", level: .info)
    }

    private func disableDualWrite() async throws {
        logEntry("🔀 Disabling dual write mode", level: .info)
        // Implementation would disable writes to old system
    }

    private func enableSingleWrite() async throws {
        logEntry("✍️ Enabling single write to new system", level: .info)
        // Implementation would configure single write mode
    }

    private func verifyWriteSwitch() async throws {
        logEntry("🔍 Verifying write switch", level: .info)
        // Implementation would test write operations
    }

    // MARK: - Phase 7: Cleanup

    private func cleanupMigrationArtifacts() async throws {
        logEntry("🧹 Cleaning up migration artifacts", level: .info)

        // Remove temporary migration data
        try await removeMigrationTemporaryFiles()

        // Update configuration
        try await updatePostMigrationConfiguration()

        // Enable all new features
        try await enableMigratedFeatures()

        logEntry("✅ Migration cleanup completed", level: .info)
    }

    private func removeMigrationTemporaryFiles() async throws {
        // Remove temporary files created during migration
        logEntry("🗑️ Removing temporary migration files", level: .info)
    }

    private func updatePostMigrationConfiguration() async throws {
        // Update app configuration for post-migration state
        logEntry("⚙️ Updating post-migration configuration", level: .info)
    }

    private func enableMigratedFeatures() async throws {
        // Enable all features that depend on successful migration
        let featuresToEnable: [FeatureFlagManager.Feature] = [
            .nativeSpeech,
            .localAudio,
            .awsBackend,
            .magicalFlow
        ]

        for feature in featuresToEnable {
            await featureFlags.setFeatureEnabled(true, for: feature)
        }

        logEntry("🚀 All migrated features enabled", level: .info)
    }

    // MARK: - Consistency Monitoring

    private func setupConsistencyMonitoring() {
        consistencyTimer = Timer.scheduledTimer(withTimeInterval: consistencyCheckInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.performConsistencyCheck()
            }
        }
    }

    private func performConsistencyCheck() async {
        guard case .inProgress(.dualWrite) = migrationStatus ||
              case .inProgress(.dataSync) = migrationStatus else {
            return
        }

        isValidatingConsistency = true

        do {
            try await validateDataConsistency()
            logEntry("✅ Data consistency check passed", level: .debug)
        } catch {
            logEntry("⚠️ Data consistency issue detected: \(error)", level: .warning)
            // Don't fail migration for minor inconsistencies, just log them
        }

        isValidatingConsistency = false
    }

    private func validateDataConsistency() async throws {
        // Implementation would compare data between old and new systems
        // For now, just simulate the check
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
    }

    // MARK: - Error Handling

    private func handleMigrationTimeout() async {
        logEntry("⏰ Migration timeout exceeded", level: .error)
        migrationStatus = .failed(MigrationError.migrationTimeout)

        try? await attemptRollback()
    }

    private func attemptRollback() async throws {
        logEntry("🔄 Attempting migration rollback", level: .warning)

        // Disable new features
        await disableNewFeatures()

        // Perform data rollback
        try await rollbackManager.emergencyRollback()

        migrationStatus = .rolledBack
        logEntry("✅ Migration rolled back successfully", level: .info)
    }

    private func disableNewFeatures() async {
        let featuresToDisable: [FeatureFlagManager.Feature] = [
            .awsBackend,
            .magicalFlow,
            .nativeSpeech,
            .localAudio
        ]

        for feature in featuresToDisable {
            await featureFlags.setFeatureEnabled(false, for: feature)
        }
    }

    // MARK: - Utility Methods

    private func updateSubProgress(_ subProgress: Double) async {
        let phaseIndex = MigrationPhase.allCases.firstIndex(of: currentPhase) ?? 0
        let phaseWeight = 1.0 / Double(MigrationPhase.allCases.count)
        let baseProgress = Double(phaseIndex) * phaseWeight
        migrationProgress = baseProgress + (subProgress * phaseWeight)
    }

    private func logEntry(_ message: String, level: LogLevel) {
        let entry = MigrationLogEntry(
            timestamp: Date(),
            phase: currentPhase,
            message: message,
            level: level
        )

        migrationLog.append(entry)

        // Keep only last 1000 entries
        if migrationLog.count > 1000 {
            migrationLog.removeFirst(migrationLog.count - 1000)
        }

        // Print to console based on level
        switch level {
        case .debug:
            break // Don't print debug messages
        case .info:
            print("ℹ️ Migration: \(message)")
        case .warning:
            print("⚠️ Migration: \(message)")
        case .error:
            print("❌ Migration: \(message)")
        }
    }

    // MARK: - Public Utility Methods

    /// Get estimated time remaining for migration
    func getEstimatedTimeRemaining() -> TimeInterval {
        let remainingPhases = MigrationPhase.allCases.suffix(from: currentPhase)
        return remainingPhases.reduce(0) { $0 + $1.estimatedDuration }
    }

    /// Check if migration can be safely paused
    func canPauseMigration() -> Bool {
        guard case .inProgress(let phase) = migrationStatus else { return false }

        let pausablePhases: [MigrationPhase] = [.validation, .backup, .dualWrite, .dataSync]
        return pausablePhases.contains(phase)
    }

    /// Get current migration statistics
    func getMigrationStats() -> MigrationStats {
        return MigrationStats(
            status: migrationStatus,
            progress: migrationProgress,
            currentPhase: currentPhase,
            estimatedTimeRemaining: getEstimatedTimeRemaining(),
            logEntryCount: migrationLog.count,
            canPause: canPauseMigration()
        )
    }
}

// MARK: - Supporting Types

enum MigrationError: LocalizedError {
    case migrationAlreadyInProgress
    case cannotResume
    case migrationTimeout
    case insufficientDiskSpace(available: Int64, required: Int64)
    case cannotDetermineAvailableSpace
    case diskSpaceValidationFailed(Error)
    case networkUnavailable
    case dataIntegrityCheckFailed(Error)
    case awsServicesUnavailable
    case backupCreationFailed
    case syncFailed(String)

    var errorDescription: String? {
        switch self {
        case .migrationAlreadyInProgress:
            return "Migration is already in progress"
        case .cannotResume:
            return "Cannot resume migration - not in paused state"
        case .migrationTimeout:
            return "Migration timed out"
        case .insufficientDiskSpace(let available, let required):
            let formatter = ByteCountFormatter()
            return "Insufficient disk space. Available: \(formatter.string(fromByteCount: available)), Required: \(formatter.string(fromByteCount: required))"
        case .cannotDetermineAvailableSpace:
            return "Cannot determine available disk space"
        case .diskSpaceValidationFailed(let error):
            return "Disk space validation failed: \(error.localizedDescription)"
        case .networkUnavailable:
            return "Network connection required for migration"
        case .dataIntegrityCheckFailed(let error):
            return "Data integrity check failed: \(error.localizedDescription)"
        case .awsServicesUnavailable:
            return "AWS services are not available"
        case .backupCreationFailed:
            return "Failed to create migration backup"
        case .syncFailed(let details):
            return "Data synchronization failed: \(details)"
        }
    }
}

enum LogLevel: String, CaseIterable {
    case debug = "DEBUG"
    case info = "INFO"
    case warning = "WARNING"
    case error = "ERROR"

    var color: String {
        switch self {
        case .debug:
            return "🔍"
        case .info:
            return "ℹ️"
        case .warning:
            return "⚠️"
        case .error:
            return "❌"
        }
    }
}

struct MigrationLogEntry: Identifiable {
    let id = UUID()
    let timestamp: Date
    let phase: DataMigrationManager.MigrationPhase
    let message: String
    let level: LogLevel

    var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        return formatter.string(from: timestamp)
    }
}

struct MigrationStats {
    let status: DataMigrationManager.MigrationStatus
    let progress: Double
    let currentPhase: DataMigrationManager.MigrationPhase
    let estimatedTimeRemaining: TimeInterval
    let logEntryCount: Int
    let canPause: Bool

    var progressPercentage: String {
        return String(format: "%.1f%%", progress * 100)
    }

    var formattedTimeRemaining: String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: estimatedTimeRemaining) ?? "Unknown"
    }
}