import Foundation
import Combine

@MainActor
class FeatureFlagManager: ObservableObject {
    static let shared = FeatureFlagManager()

    // MARK: - Published Properties
    @Published private(set) var flags: [String: FeatureFlagConfig] = [:]
    @Published private(set) var isLoading = false
    @Published private(set) var lastUpdateTime: Date?

    // MARK: - Feature Flags
    enum Feature: String, CaseIterable {
        case nativeSpeech = "native_speech_enabled"
        case localAudio = "local_audio_enabled"
        case awsBackend = "aws_backend_enabled"
        case magicalFlow = "magical_flow_enabled"
        case cloudKitSync = "cloudkit_sync_enabled"
        case enhancedVoices = "enhanced_voices_enabled"
        case audioStitching = "audio_stitching_enabled"
        case waveformVisualization = "waveform_visualization_enabled"
        case dailyQuestions = "daily_questions_enabled"
        case offlineMode = "offline_mode_enabled"

        var defaultValue: Bool {
            switch self {
            case .nativeSpeech, .localAudio, .dailyQuestions:
                return true  // Core features enabled by default
            case .awsBackend, .magicalFlow:
                return false // New features start disabled
            case .cloudKitSync, .enhancedVoices:
                return false // Premium features
            case .audioStitching, .waveformVisualization:
                return true  // UI features enabled
            case .offlineMode:
                return true  // Always available
            }
        }

        var description: String {
            switch self {
            case .nativeSpeech:
                return "Use native iOS speech synthesis instead of Polly"
            case .localAudio:
                return "Store audio files locally on device"
            case .awsBackend:
                return "Use AWS Lambda backend for question generation"
            case .magicalFlow:
                return "Enable seamless interview flow without manual controls"
            case .cloudKitSync:
                return "Sync data across devices using CloudKit"
            case .enhancedVoices:
                return "Download and use enhanced voice quality"
            case .audioStitching:
                return "Combine audio segments into single podcast file"
            case .waveformVisualization:
                return "Show real-time waveform visualization"
            case .dailyQuestions:
                return "Custom daily questions feature"
            case .offlineMode:
                return "Continue working without network connection"
            }
        }
    }

    // MARK: - User Groups for Gradual Rollout
    enum UserGroup: String, CaseIterable {
        case beta = "beta"
        case earlyAdopters = "early_adopters"
        case mainstream = "mainstream"
        case conservative = "conservative"
        case internal = "internal"

        var rolloutPercentage: Double {
            switch self {
            case .internal:
                return 100.0  // Internal users get everything
            case .beta:
                return 10.0   // 10% beta users
            case .earlyAdopters:
                return 25.0   // 25% early adopters
            case .mainstream:
                return 50.0   // 50% mainstream
            case .conservative:
                return 0.0    // Conservative users wait
            }
        }
    }

    // MARK: - Configuration
    private let userDefaults = UserDefaults.standard
    private let remoteConfigService = RemoteConfigService()
    private var cancellables = Set<AnyCancellable>()

    // Cache keys
    private let flagsCacheKey = "feature_flags_cache"
    private let lastUpdateKey = "feature_flags_last_update"

    private init() {
        loadCachedFlags()
        setupPeriodicUpdates()
    }

    // MARK: - Public Interface

    /// Check if a feature is enabled for the current user
    func isEnabled(_ feature: Feature) -> Bool {
        return isEnabled(feature, for: getCurrentUserId())
    }

    /// Check if a feature is enabled for a specific user
    func isEnabled(_ feature: Feature, for userId: String) -> Bool {
        // Check if feature is explicitly disabled
        if let flag = flags[feature.rawValue], !flag.enabled {
            return false
        }

        // Check rollout percentage
        let userGroup = getUserGroup(userId)
        let rolloutPercentage = getRolloutPercentage(for: feature)

        // Internal users always get features
        if userGroup == .internal {
            return true
        }

        // Check if user falls within rollout percentage
        let userHash = generateStableHash(userId)
        return (userHash % 100) < Int(rolloutPercentage)
    }

    /// Get rollout percentage for a feature
    func getRolloutPercentage(for feature: Feature) -> Double {
        if let flag = flags[feature.rawValue] {
            return flag.rolloutPercentage
        }
        return feature.defaultValue ? 100.0 : 0.0
    }

    /// Update rollout percentage for a feature (admin function)
    func updateRolloutPercentage(_ percentage: Double, for feature: Feature) async {
        var updatedFlag = flags[feature.rawValue] ?? FeatureFlagConfig(
            key: feature.rawValue,
            enabled: feature.defaultValue,
            rolloutPercentage: 0.0
        )

        updatedFlag.rolloutPercentage = min(100.0, max(0.0, percentage))
        updatedFlag.lastModified = Date()

        flags[feature.rawValue] = updatedFlag

        // Save to cache
        saveFlagsToCache()

        // Sync to remote if possible
        await syncToRemote()
    }

    /// Enable/disable a feature entirely (kill switch)
    func setFeatureEnabled(_ enabled: Bool, for feature: Feature) async {
        var updatedFlag = flags[feature.rawValue] ?? FeatureFlagConfig(
            key: feature.rawValue,
            enabled: feature.defaultValue,
            rolloutPercentage: 0.0
        )

        updatedFlag.enabled = enabled
        updatedFlag.lastModified = Date()

        flags[feature.rawValue] = updatedFlag

        saveFlagsToCache()
        await syncToRemote()

        print("🚩 Feature \(feature.rawValue) \(enabled ? "enabled" : "disabled")")
    }

    /// Emergency kill switch - disable all features
    func emergencyKillSwitch() async {
        print("🚨 EMERGENCY KILL SWITCH ACTIVATED")

        for feature in Feature.allCases {
            await setFeatureEnabled(false, for: feature)
        }

        // Force immediate sync
        await syncToRemote()
    }

    /// Refresh flags from remote config
    func refreshFlags() async {
        isLoading = true

        do {
            let remoteFlags = try await remoteConfigService.fetchFlags()

            // Merge with local flags, remote takes precedence
            for remoteFlag in remoteFlags {
                flags[remoteFlag.key] = remoteFlag
            }

            lastUpdateTime = Date()
            saveFlagsToCache()

            print("✅ Feature flags refreshed from remote")

        } catch {
            print("⚠️ Failed to refresh feature flags: \(error)")
            // Continue with cached flags
        }

        isLoading = false
    }

    // MARK: - User Group Management

    private func getCurrentUserId() -> String {
        // Get from auth service or generate anonymous ID
        if let userId = AuthService.shared.currentUserId {
            return userId
        }

        // Generate stable anonymous ID for non-authenticated users
        if let deviceId = UIDevice.current.identifierForVendor?.uuidString {
            return "anonymous_\(deviceId)"
        }

        return "anonymous_unknown"
    }

    private func getUserGroup(_ userId: String) -> UserGroup {
        // Check if user is internal (employee, tester, etc.)
        if isInternalUser(userId) {
            return .internal
        }

        // Check user's opted-in group
        if let savedGroup = userDefaults.string(forKey: "user_group_\(userId)"),
           let group = UserGroup(rawValue: savedGroup) {
            return group
        }

        // Default assignment based on user hash
        let userHash = generateStableHash(userId)
        let groupIndex = userHash % UInt32(UserGroup.allCases.count - 1) // Exclude internal
        return UserGroup.allCases[Int(groupIndex)]
    }

    private func isInternalUser(_ userId: String) -> Bool {
        // Check against internal user list or email domain
        let internalDomains = ["@inkra.io", "@company.com"]
        return internalDomains.contains { userId.contains($0) }
    }

    /// Allow users to opt into beta testing
    func optInToBeta(_ userId: String) {
        userDefaults.set(UserGroup.beta.rawValue, forKey: "user_group_\(userId)")
        print("🧪 User \(userId) opted into beta testing")
    }

    /// Allow users to opt out of beta testing
    func optOutOfBeta(_ userId: String) {
        userDefaults.set(UserGroup.conservative.rawValue, forKey: "user_group_\(userId)")
        print("🔒 User \(userId) opted out of beta testing")
    }

    // MARK: - Analytics & Monitoring

    /// Track feature usage for analytics
    func trackFeatureUsage(_ feature: Feature, action: String) {
        let event = FeatureUsageEvent(
            feature: feature.rawValue,
            action: action,
            userId: getCurrentUserId(),
            timestamp: Date(),
            enabled: isEnabled(feature)
        )

        AnalyticsService.shared.track(event)
    }

    /// Get feature usage statistics
    func getFeatureStats(_ feature: Feature) -> FeatureStats {
        let enabled = isEnabled(feature)
        let rolloutPercentage = getRolloutPercentage(for: feature)
        let userGroup = getUserGroup(getCurrentUserId())

        return FeatureStats(
            feature: feature,
            enabled: enabled,
            rolloutPercentage: rolloutPercentage,
            userGroup: userGroup,
            lastChecked: Date()
        )
    }

    // MARK: - Private Helpers

    private func generateStableHash(_ input: String) -> UInt32 {
        var hash: UInt32 = 0
        for char in input.utf8 {
            hash = hash &* 31 &+ UInt32(char)
        }
        return hash
    }

    private func loadCachedFlags() {
        if let data = userDefaults.data(forKey: flagsCacheKey),
           let cachedFlags = try? JSONDecoder().decode([String: FeatureFlagConfig].self, from: data) {
            flags = cachedFlags
        }

        if let lastUpdate = userDefaults.object(forKey: lastUpdateKey) as? Date {
            lastUpdateTime = lastUpdate
        }

        // Initialize default flags if none exist
        if flags.isEmpty {
            initializeDefaultFlags()
        }
    }

    private func saveFlagsToCache() {
        if let data = try? JSONEncoder().encode(flags) {
            userDefaults.set(data, forKey: flagsCacheKey)
        }

        if let lastUpdate = lastUpdateTime {
            userDefaults.set(lastUpdate, forKey: lastUpdateKey)
        }
    }

    private func initializeDefaultFlags() {
        for feature in Feature.allCases {
            flags[feature.rawValue] = FeatureFlagConfig(
                key: feature.rawValue,
                enabled: feature.defaultValue,
                rolloutPercentage: feature.defaultValue ? 100.0 : 0.0
            )
        }
        saveFlagsToCache()
    }

    private func setupPeriodicUpdates() {
        // Refresh flags every 5 minutes
        Timer.publish(every: 300, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task {
                    await self?.refreshFlags()
                }
            }
            .store(in: &cancellables)
    }

    private func syncToRemote() async {
        do {
            try await remoteConfigService.syncFlags(Array(flags.values))
            print("✅ Feature flags synced to remote")
        } catch {
            print("⚠️ Failed to sync feature flags: \(error)")
        }
    }
}

// MARK: - Supporting Types

struct FeatureFlagConfig: Codable {
    let key: String
    var enabled: Bool
    var rolloutPercentage: Double
    var lastModified: Date = Date()
    var metadata: [String: String] = [:]
}

struct FeatureUsageEvent {
    let feature: String
    let action: String
    let userId: String
    let timestamp: Date
    let enabled: Bool
}

struct FeatureStats {
    let feature: FeatureFlagManager.Feature
    let enabled: Bool
    let rolloutPercentage: Double
    let userGroup: FeatureFlagManager.UserGroup
    let lastChecked: Date
}

// MARK: - Remote Config Service

class RemoteConfigService {
    func fetchFlags() async throws -> [FeatureFlagConfig] {
        // In a real implementation, this would fetch from AWS AppConfig,
        // Firebase Remote Config, or similar service

        // For now, return empty array (use local defaults)
        return []
    }

    func syncFlags(_ flags: [FeatureFlagConfig]) async throws {
        // In a real implementation, this would sync to remote config service
        print("📡 Syncing \(flags.count) flags to remote config")
    }
}

// MARK: - Mock Services (to be replaced with real implementations)

class AuthService {
    static let shared = AuthService()
    var currentUserId: String? = nil
}

class AnalyticsService {
    static let shared = AnalyticsService()

    func track(_ event: FeatureUsageEvent) {
        print("📊 Feature usage: \(event.feature) - \(event.action)")
    }
}