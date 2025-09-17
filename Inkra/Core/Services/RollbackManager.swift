import Foundation
import CoreData

@MainActor
class RollbackManager: ObservableObject {
    static let shared = RollbackManager()

    // MARK: - Published Properties
    @Published private(set) var isRollbackInProgress = false
    @Published private(set) var rollbackStatus: RollbackStatus = .ready
    @Published private(set) var availableBackups: [BackupVersion] = []
    @Published private(set) var currentVersion: String = "2.0.0"

    // MARK: - Services
    private let dataManager = DataManager.shared
    private let networkService = NetworkService.shared
    private let fileManager = FileManager.default

    // MARK: - Constants
    private let backupDirectory = "Backups"
    private let maxBackupsToKeep = 10
    private let rollbackTimeoutSeconds: TimeInterval = 1800 // 30 minutes

    enum RollbackStatus {
        case ready
        case creatingBackup
        case rollingBack
        case completed
        case failed(Error)
    }

    enum RollbackError: LocalizedError {
        case backupNotFound(String)
        case incompatibleVersion(String, String)
        case dataCorruption
        case networkUnavailable
        case timeoutExceeded
        case userDataValidationFailed

        var errorDescription: String? {
            switch self {
            case .backupNotFound(let version):
                return "Backup for version \(version) not found"
            case .incompatibleVersion(let from, let to):
                return "Cannot rollback from \(from) to \(to) - incompatible versions"
            case .dataCorruption:
                return "Data corruption detected during rollback"
            case .networkUnavailable:
                return "Network connection required for rollback"
            case .timeoutExceeded:
                return "Rollback operation timed out"
            case .userDataValidationFailed:
                return "User data validation failed after rollback"
            }
        }
    }

    private init() {
        loadAvailableBackups()
    }

    // MARK: - Backup Management

    /// Create a backup before major changes
    func createBackup(version: String, description: String) async throws -> BackupVersion {
        rollbackStatus = .creatingBackup

        print("📦 Creating backup for version \(version)")

        let backup = BackupVersion(
            version: version,
            description: description,
            timestamp: Date(),
            size: 0
        )

        do {
            // Create backup directory
            let backupPath = try createBackupDirectory(for: backup)

            // Backup CoreData
            let coreDataSize = try await backupCoreData(to: backupPath)

            // Backup audio files
            let audioSize = try await backupAudioFiles(to: backupPath)

            // Backup user preferences
            let prefsSize = try await backupUserPreferences(to: backupPath)

            // Backup app state
            let stateSize = try await backupAppState(to: backupPath)

            // Update backup with total size
            let totalSize = coreDataSize + audioSize + prefsSize + stateSize
            let finalBackup = BackupVersion(
                version: backup.version,
                description: backup.description,
                timestamp: backup.timestamp,
                size: totalSize,
                path: backupPath
            )

            // Save backup metadata
            try saveBackupMetadata(finalBackup)

            // Add to available backups
            availableBackups.append(finalBackup)
            availableBackups.sort { $0.timestamp > $1.timestamp }

            // Clean up old backups
            try cleanupOldBackups()

            rollbackStatus = .ready

            print("✅ Backup created successfully: \(formatFileSize(totalSize))")
            return finalBackup

        } catch {
            rollbackStatus = .failed(error)
            throw error
        }
    }

    /// Check if rollback is possible between versions
    func canRollback(from currentVersion: String, to targetVersion: String) -> Bool {
        // Check version compatibility matrix
        let compatibility = VersionCompatibility()
        return compatibility.isRollbackSupported(from: currentVersion, to: targetVersion)
    }

    /// Perform rollback to a specific backup
    func performRollback(to backup: BackupVersion) async throws {
        guard !isRollbackInProgress else {
            throw RollbackError.networkUnavailable
        }

        isRollbackInProgress = true
        rollbackStatus = .rollingBack

        print("🔄 Starting rollback to version \(backup.version)")

        // Start timeout timer
        let timeoutTask = Task {
            try await Task.sleep(nanoseconds: UInt64(rollbackTimeoutSeconds * 1_000_000_000))
            if isRollbackInProgress {
                await handleRollbackTimeout()
            }
        }

        do {
            // Pre-rollback validation
            try await validateRollbackPreconditions(backup)

            // Create emergency backup of current state
            let emergencyBackup = try await createBackup(
                version: currentVersion,
                description: "Emergency backup before rollback to \(backup.version)"
            )

            // Disable features during rollback
            await disableAllFeatures()

            // Restore data in order
            try await restoreCoreData(from: backup)
            try await restoreAudioFiles(from: backup)
            try await restoreUserPreferences(from: backup)
            try await restoreAppState(from: backup)

            // Validate restored data
            try await validateRestoredData(backup)

            // Update current version
            currentVersion = backup.version

            // Re-enable compatible features
            await enableCompatibleFeatures(for: backup.version)

            rollbackStatus = .completed
            print("✅ Rollback completed successfully")

        } catch {
            rollbackStatus = .failed(error)
            print("❌ Rollback failed: \(error)")

            // Attempt emergency recovery
            try await attemptEmergencyRecovery()
            throw error
        }

        timeoutTask.cancel()
        isRollbackInProgress = false
    }

    /// Emergency rollback (fastest possible)
    func emergencyRollback() async throws {
        print("🚨 EMERGENCY ROLLBACK INITIATED")

        guard let latestBackup = availableBackups.first else {
            throw RollbackError.backupNotFound("No backups available")
        }

        // Skip validation for speed
        isRollbackInProgress = true
        rollbackStatus = .rollingBack

        try await restoreCoreData(from: latestBackup)
        await disableAllFeatures()

        currentVersion = latestBackup.version
        rollbackStatus = .completed
        isRollbackInProgress = false

        print("✅ Emergency rollback completed")
    }

    // MARK: - Backup Operations

    private func createBackupDirectory(for backup: BackupVersion) throws -> URL {
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let backupRoot = documentsURL.appendingPathComponent(backupDirectory)

        // Create root backup directory if needed
        if !fileManager.fileExists(atPath: backupRoot.path) {
            try fileManager.createDirectory(at: backupRoot, withIntermediateDirectories: true)
        }

        // Create version-specific directory
        let timestamp = DateFormatter.backupFormatter.string(from: backup.timestamp)
        let backupPath = backupRoot.appendingPathComponent("\(backup.version)_\(timestamp)")

        try fileManager.createDirectory(at: backupPath, withIntermediateDirectories: true)

        return backupPath
    }

    private func backupCoreData(to backupPath: URL) async throws -> Int64 {
        let context = dataManager.backgroundContext

        return try await context.perform {
            let storeURL = self.dataManager.persistentContainer.persistentStoreDescriptions.first?.url
            guard let sourceURL = storeURL else {
                throw RollbackError.dataCorruption
            }

            let targetURL = backupPath.appendingPathComponent("CoreData.sqlite")

            // Copy main database file
            try self.fileManager.copyItem(at: sourceURL, to: targetURL)

            // Copy WAL and SHM files if they exist
            let walSource = sourceURL.appendingPathExtension("sqlite-wal")
            let shmSource = sourceURL.appendingPathExtension("sqlite-shm")

            if self.fileManager.fileExists(atPath: walSource.path) {
                let walTarget = targetURL.appendingPathExtension("sqlite-wal")
                try self.fileManager.copyItem(at: walSource, to: walTarget)
            }

            if self.fileManager.fileExists(atPath: shmSource.path) {
                let shmTarget = targetURL.appendingPathExtension("sqlite-shm")
                try self.fileManager.copyItem(at: shmSource, to: shmTarget)
            }

            // Calculate size
            let attributes = try self.fileManager.attributesOfItem(atPath: targetURL.path)
            return attributes[.size] as? Int64 ?? 0
        }
    }

    private func backupAudioFiles(to backupPath: URL) async throws -> Int64 {
        let audioDirectory = try LocalAudioManager.shared.getAudioDirectory()
        let targetDirectory = backupPath.appendingPathComponent("AudioFiles")

        try fileManager.createDirectory(at: targetDirectory, withIntermediateDirectories: true)

        // Copy all audio files
        let audioFiles = try fileManager.contentsOfDirectory(at: audioDirectory, includingPropertiesForKeys: [.fileSizeKey])
        var totalSize: Int64 = 0

        for audioFile in audioFiles {
            let targetFile = targetDirectory.appendingPathComponent(audioFile.lastPathComponent)
            try fileManager.copyItem(at: audioFile, to: targetFile)

            let attributes = try fileManager.attributesOfItem(atPath: targetFile.path)
            totalSize += attributes[.size] as? Int64 ?? 0
        }

        return totalSize
    }

    private func backupUserPreferences(to backupPath: URL) async throws -> Int64 {
        let prefsFile = backupPath.appendingPathComponent("UserDefaults.plist")

        // Export UserDefaults to plist
        let userDefaults = UserDefaults.standard
        let prefsDict = userDefaults.dictionaryRepresentation()

        // Filter only app-specific keys
        let filteredPrefs = prefsDict.filter { key, _ in
            key.hasPrefix("com.inkra.") || key.hasPrefix("inkra_")
        }

        let data = try PropertyListSerialization.data(fromPropertyList: filteredPrefs, format: .xml, options: 0)
        try data.write(to: prefsFile)

        let attributes = try fileManager.attributesOfItem(atPath: prefsFile.path)
        return attributes[.size] as? Int64 ?? 0
    }

    private func backupAppState(to backupPath: URL) async throws -> Int64 {
        let stateFile = backupPath.appendingPathComponent("AppState.json")

        let appState = AppState(
            version: currentVersion,
            featureFlags: FeatureFlagManager.shared.flags,
            lastInterviewDate: UserDefaults.standard.object(forKey: "last_interview_date") as? Date,
            userOnboardingComplete: UserDefaults.standard.bool(forKey: "onboarding_complete"),
            selectedVoiceId: UserDefaults.standard.string(forKey: "selected_voice_id")
        )

        let data = try JSONEncoder().encode(appState)
        try data.write(to: stateFile)

        let attributes = try fileManager.attributesOfItem(atPath: stateFile.path)
        return attributes[.size] as? Int64 ?? 0
    }

    // MARK: - Restore Operations

    private func restoreCoreData(from backup: BackupVersion) async throws {
        guard let backupPath = backup.path else {
            throw RollbackError.backupNotFound(backup.version)
        }

        let context = dataManager.backgroundContext

        try await context.perform {
            let storeURL = self.dataManager.persistentContainer.persistentStoreDescriptions.first?.url
            guard let targetURL = storeURL else {
                throw RollbackError.dataCorruption
            }

            let sourceURL = backupPath.appendingPathComponent("CoreData.sqlite")

            // Close existing store
            let coordinator = self.dataManager.persistentContainer.persistentStoreCoordinator
            if let store = coordinator.persistentStores.first {
                try coordinator.remove(store)
            }

            // Remove existing database files
            try? self.fileManager.removeItem(at: targetURL)
            try? self.fileManager.removeItem(at: targetURL.appendingPathExtension("sqlite-wal"))
            try? self.fileManager.removeItem(at: targetURL.appendingPathExtension("sqlite-shm"))

            // Copy backup files
            try self.fileManager.copyItem(at: sourceURL, to: targetURL)

            let walSource = sourceURL.appendingPathExtension("sqlite-wal")
            let shmSource = sourceURL.appendingPathExtension("sqlite-shm")

            if self.fileManager.fileExists(atPath: walSource.path) {
                let walTarget = targetURL.appendingPathExtension("sqlite-wal")
                try self.fileManager.copyItem(at: walSource, to: walTarget)
            }

            if self.fileManager.fileExists(atPath: shmSource.path) {
                let shmTarget = targetURL.appendingPathExtension("sqlite-shm")
                try self.fileManager.copyItem(at: shmSource, to: shmTarget)
            }

            // Reload store
            try coordinator.addPersistentStore(
                ofType: NSSQLiteStoreType,
                configurationName: nil,
                at: targetURL,
                options: self.dataManager.storeOptions
            )
        }
    }

    private func restoreAudioFiles(from backup: BackupVersion) async throws {
        guard let backupPath = backup.path else {
            throw RollbackError.backupNotFound(backup.version)
        }

        let audioDirectory = try LocalAudioManager.shared.getAudioDirectory()
        let sourceDirectory = backupPath.appendingPathComponent("AudioFiles")

        // Remove existing audio files
        try fileManager.removeItem(at: audioDirectory)
        try fileManager.createDirectory(at: audioDirectory, withIntermediateDirectories: true)

        // Copy backup audio files
        let backupFiles = try fileManager.contentsOfDirectory(at: sourceDirectory, includingPropertiesForKeys: nil)

        for backupFile in backupFiles {
            let targetFile = audioDirectory.appendingPathComponent(backupFile.lastPathComponent)
            try fileManager.copyItem(at: backupFile, to: targetFile)
        }
    }

    private func restoreUserPreferences(from backup: BackupVersion) async throws {
        guard let backupPath = backup.path else {
            throw RollbackError.backupNotFound(backup.version)
        }

        let prefsFile = backupPath.appendingPathComponent("UserDefaults.plist")
        let data = try Data(contentsOf: prefsFile)

        let prefsDict = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]

        // Restore preferences
        let userDefaults = UserDefaults.standard
        prefsDict?.forEach { key, value in
            userDefaults.set(value, forKey: key)
        }

        userDefaults.synchronize()
    }

    private func restoreAppState(from backup: BackupVersion) async throws {
        guard let backupPath = backup.path else {
            throw RollbackError.backupNotFound(backup.version)
        }

        let stateFile = backupPath.appendingPathComponent("AppState.json")
        let data = try Data(contentsOf: stateFile)
        let appState = try JSONDecoder().decode(AppState.self, from: data)

        // Restore app state
        if let lastInterviewDate = appState.lastInterviewDate {
            UserDefaults.standard.set(lastInterviewDate, forKey: "last_interview_date")
        }

        UserDefaults.standard.set(appState.userOnboardingComplete, forKey: "onboarding_complete")

        if let voiceId = appState.selectedVoiceId {
            UserDefaults.standard.set(voiceId, forKey: "selected_voice_id")
        }

        // Restore feature flags
        FeatureFlagManager.shared.flags = appState.featureFlags
    }

    // MARK: - Validation

    private func validateRollbackPreconditions(_ backup: BackupVersion) async throws {
        // Check if backup exists and is valid
        guard let backupPath = backup.path,
              fileManager.fileExists(atPath: backupPath.path) else {
            throw RollbackError.backupNotFound(backup.version)
        }

        // Check version compatibility
        if !canRollback(from: currentVersion, to: backup.version) {
            throw RollbackError.incompatibleVersion(currentVersion, backup.version)
        }

        // Check network availability for emergency recovery
        if !networkService.isConnected {
            print("⚠️ Warning: Network unavailable for emergency recovery")
        }

        // Validate backup integrity
        try await validateBackupIntegrity(backup)
    }

    private func validateBackupIntegrity(_ backup: BackupVersion) async throws {
        guard let backupPath = backup.path else {
            throw RollbackError.backupNotFound(backup.version)
        }

        // Check if all required backup files exist
        let requiredFiles = ["CoreData.sqlite", "UserDefaults.plist", "AppState.json"]

        for fileName in requiredFiles {
            let filePath = backupPath.appendingPathComponent(fileName)
            if !fileManager.fileExists(atPath: filePath.path) {
                throw RollbackError.dataCorruption
            }
        }

        // Validate CoreData backup
        let coreDataPath = backupPath.appendingPathComponent("CoreData.sqlite")
        // Add SQLite integrity check here if needed
    }

    private func validateRestoredData(_ backup: BackupVersion) async throws {
        // Validate CoreData
        let context = dataManager.viewContext
        let request: NSFetchRequest<NSManagedObject> = NSFetchRequest(entityName: "ProjectEntity")
        request.fetchLimit = 1

        do {
            _ = try context.fetch(request)
        } catch {
            throw RollbackError.userDataValidationFailed
        }

        // Validate audio files
        let audioDirectory = try LocalAudioManager.shared.getAudioDirectory()
        if !fileManager.fileExists(atPath: audioDirectory.path) {
            throw RollbackError.userDataValidationFailed
        }

        print("✅ Data validation passed")
    }

    // MARK: - Feature Management During Rollback

    private func disableAllFeatures() async {
        for feature in FeatureFlagManager.Feature.allCases {
            await FeatureFlagManager.shared.setFeatureEnabled(false, for: feature)
        }
    }

    private func enableCompatibleFeatures(for version: String) async {
        let compatibility = VersionCompatibility()
        let compatibleFeatures = compatibility.getCompatibleFeatures(for: version)

        for feature in compatibleFeatures {
            await FeatureFlagManager.shared.setFeatureEnabled(true, for: feature)
        }
    }

    // MARK: - Emergency Recovery

    private func handleRollbackTimeout() async {
        print("⏰ Rollback timeout - initiating emergency recovery")
        rollbackStatus = .failed(RollbackError.timeoutExceeded)

        try? await emergencyRollback()
    }

    private func attemptEmergencyRecovery() async throws {
        print("🚨 Attempting emergency recovery")

        // Try to restore to the most recent backup
        if let latestBackup = availableBackups.first {
            try await restoreCoreData(from: latestBackup)
            await disableAllFeatures()
        } else {
            // Factory reset as last resort
            try await performFactoryReset()
        }
    }

    private func performFactoryReset() async throws {
        print("🏭 Performing factory reset")

        // Reset CoreData
        let context = dataManager.backgroundContext
        try await context.perform {
            let entities = self.dataManager.persistentContainer.managedObjectModel.entities
            for entity in entities {
                if let entityName = entity.name {
                    let request = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
                    let deleteRequest = NSBatchDeleteRequest(fetchRequest: request)
                    try context.execute(deleteRequest)
                }
            }
            try context.save()
        }

        // Clear user defaults
        let userDefaults = UserDefaults.standard
        let dictionary = userDefaults.dictionaryRepresentation()
        dictionary.keys.forEach { key in
            if key.hasPrefix("com.inkra.") || key.hasPrefix("inkra_") {
                userDefaults.removeObject(forKey: key)
            }
        }

        // Clear audio files
        let audioDirectory = try LocalAudioManager.shared.getAudioDirectory()
        try? fileManager.removeItem(at: audioDirectory)
        try fileManager.createDirectory(at: audioDirectory, withIntermediateDirectories: true)

        print("✅ Factory reset completed")
    }

    // MARK: - Utility Methods

    private func loadAvailableBackups() {
        // Load backup metadata from storage
        // Implementation would load from persistent storage
    }

    private func saveBackupMetadata(_ backup: BackupVersion) throws {
        // Save backup metadata for future reference
        // Implementation would save to persistent storage
    }

    private func cleanupOldBackups() throws {
        // Keep only the most recent backups
        if availableBackups.count > maxBackupsToKeep {
            let backupsToRemove = availableBackups.dropFirst(maxBackupsToKeep)

            for backup in backupsToRemove {
                if let path = backup.path {
                    try? fileManager.removeItem(at: path)
                }
            }

            availableBackups = Array(availableBackups.prefix(maxBackupsToKeep))
        }
    }

    private func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

// MARK: - Supporting Types

struct BackupVersion: Codable, Identifiable {
    let id = UUID()
    let version: String
    let description: String
    let timestamp: Date
    let size: Int64
    var path: URL?

    var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }

    var formattedDate: String {
        return DateFormatter.userFriendly.string(from: timestamp)
    }
}

struct AppState: Codable {
    let version: String
    let featureFlags: [String: Bool]
    let lastInterviewDate: Date?
    let userOnboardingComplete: Bool
    let selectedVoiceId: String?
}

class VersionCompatibility {
    func isRollbackSupported(from: String, to: String) -> Bool {
        // Simple version comparison - in reality this would be more complex
        return from.compare(to, options: .numeric) == .orderedDescending
    }

    func getCompatibleFeatures(for version: String) -> [String] {
        // Return features compatible with the given version
        switch version {
        case "1.0.0":
            return ["dailyQuestions", "offlineMode"]
        case "2.0.0":
            return ["nativeSpeech", "localAudio", "dailyQuestions", "offlineMode"]
        default:
            return ["dailyQuestions", "offlineMode", "nativeSpeech", "localAudio"]
        }
    }
}

// MARK: - Extensions

extension DateFormatter {
    static let backupFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return formatter
    }()

    static let userFriendly: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}