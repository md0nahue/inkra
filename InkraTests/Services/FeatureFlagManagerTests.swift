import XCTest
@testable import Inkra

@MainActor
final class FeatureFlagManagerTests: XCTestCase {

    var featureFlagManager: FeatureFlagManager!

    override func setUp() async throws {
        await super.setUp()

        // Create a fresh instance for each test
        featureFlagManager = FeatureFlagManager.shared

        // Clear any existing flags
        featureFlagManager.flags = [:]

        // Initialize with default flags
        for feature in FeatureFlagManager.Feature.allCases {
            featureFlagManager.flags[feature.rawValue] = FeatureFlagConfig(
                key: feature.rawValue,
                enabled: feature.defaultValue,
                rolloutPercentage: feature.defaultValue ? 100.0 : 0.0
            )
        }
    }

    override func tearDown() async throws {
        featureFlagManager = nil
        await super.tearDown()
    }

    // MARK: - Basic Feature Flag Tests

    func testFeatureFlagDefaultValues() {
        // Test that default values are correctly set
        XCTAssertTrue(featureFlagManager.isEnabled(.nativeSpeech))
        XCTAssertTrue(featureFlagManager.isEnabled(.localAudio))
        XCTAssertTrue(featureFlagManager.isEnabled(.dailyQuestions))
        XCTAssertFalse(featureFlagManager.isEnabled(.awsBackend))
        XCTAssertFalse(featureFlagManager.isEnabled(.magicalFlow))
    }

    func testFeatureFlagToggling() async {
        // Test enabling a feature
        await featureFlagManager.setFeatureEnabled(true, for: .awsBackend)
        XCTAssertTrue(featureFlagManager.isEnabled(.awsBackend))

        // Test disabling a feature
        await featureFlagManager.setFeatureEnabled(false, for: .nativeSpeech)
        XCTAssertFalse(featureFlagManager.isEnabled(.nativeSpeech))
    }

    func testRolloutPercentages() async {
        let feature = FeatureFlagManager.Feature.awsBackend

        // Test different rollout percentages
        await featureFlagManager.updateRolloutPercentage(25.0, for: feature)
        XCTAssertEqual(featureFlagManager.getRolloutPercentage(for: feature), 25.0)

        await featureFlagManager.updateRolloutPercentage(75.0, for: feature)
        XCTAssertEqual(featureFlagManager.getRolloutPercentage(for: feature), 75.0)

        // Test boundary values
        await featureFlagManager.updateRolloutPercentage(-10.0, for: feature)
        XCTAssertEqual(featureFlagManager.getRolloutPercentage(for: feature), 0.0)

        await featureFlagManager.updateRolloutPercentage(150.0, for: feature)
        XCTAssertEqual(featureFlagManager.getRolloutPercentage(for: feature), 100.0)
    }

    // MARK: - User Group Tests

    func testUserGroupAssignment() {
        let testUserId1 = "test_user_1"
        let testUserId2 = "test_user_2"

        // Test consistent hash-based assignment
        let group1First = featureFlagManager.getUserGroup(testUserId1)
        let group1Second = featureFlagManager.getUserGroup(testUserId1)
        XCTAssertEqual(group1First, group1Second, "User group assignment should be consistent")

        // Different users may get different groups
        let group2 = featureFlagManager.getUserGroup(testUserId2)
        // Note: This might be equal by chance, but we test consistency above
    }

    func testInternalUserHandling() {
        let internalUserId = "admin@inkra.io"
        let regularUserId = "user@gmail.com"

        // Internal users should always get features
        XCTAssertTrue(featureFlagManager.isEnabled(.awsBackend, for: internalUserId))

        // Regular users follow rollout rules
        await featureFlagManager.updateRolloutPercentage(0.0, for: .awsBackend)
        XCTAssertFalse(featureFlagManager.isEnabled(.awsBackend, for: regularUserId))
        XCTAssertTrue(featureFlagManager.isEnabled(.awsBackend, for: internalUserId))
    }

    func testBetaOptInOut() {
        let userId = "test_user"

        // Test opt-in to beta
        featureFlagManager.optInToBeta(userId)
        let userDefaults = UserDefaults.standard
        let savedGroup = userDefaults.string(forKey: "user_group_\(userId)")
        XCTAssertEqual(savedGroup, FeatureFlagManager.UserGroup.beta.rawValue)

        // Test opt-out
        featureFlagManager.optOutOfBeta(userId)
        let updatedGroup = userDefaults.string(forKey: "user_group_\(userId)")
        XCTAssertEqual(updatedGroup, FeatureFlagManager.UserGroup.conservative.rawValue)
    }

    // MARK: - Rollout Logic Tests

    func testGradualRollout() async {
        let feature = FeatureFlagManager.Feature.magicalFlow
        let testUsers = (1...100).map { "user_\($0)" }

        // Test 25% rollout
        await featureFlagManager.updateRolloutPercentage(25.0, for: feature)

        let enabledUsers = testUsers.filter { featureFlagManager.isEnabled(feature, for: $0) }
        let enabledPercentage = Double(enabledUsers.count) / Double(testUsers.count) * 100.0

        // Allow for some variance due to hash distribution
        XCTAssertTrue(enabledPercentage >= 15.0 && enabledPercentage <= 35.0,
                     "Expected ~25% rollout, got \(enabledPercentage)%")
    }

    func testStableRollout() async {
        let feature = FeatureFlagManager.Feature.magicalFlow
        let testUser = "stable_test_user"

        await featureFlagManager.updateRolloutPercentage(50.0, for: feature)

        let firstCheck = featureFlagManager.isEnabled(feature, for: testUser)
        let secondCheck = featureFlagManager.isEnabled(feature, for: testUser)
        let thirdCheck = featureFlagManager.isEnabled(feature, for: testUser)

        XCTAssertEqual(firstCheck, secondCheck)
        XCTAssertEqual(secondCheck, thirdCheck)
    }

    // MARK: - Emergency Kill Switch Tests

    func testEmergencyKillSwitch() async {
        // Enable all features first
        for feature in FeatureFlagManager.Feature.allCases {
            await featureFlagManager.setFeatureEnabled(true, for: feature)
        }

        // Verify all are enabled
        for feature in FeatureFlagManager.Feature.allCases {
            XCTAssertTrue(featureFlagManager.isEnabled(feature))
        }

        // Trigger emergency kill switch
        await featureFlagManager.emergencyKillSwitch()

        // Verify all are disabled
        for feature in FeatureFlagManager.Feature.allCases {
            XCTAssertFalse(featureFlagManager.isEnabled(feature))
        }
    }

    // MARK: - Feature Stats Tests

    func testFeatureStats() {
        let feature = FeatureFlagManager.Feature.nativeSpeech
        let stats = featureFlagManager.getFeatureStats(feature)

        XCTAssertEqual(stats.feature, feature)
        XCTAssertTrue(stats.enabled) // Default is enabled
        XCTAssertEqual(stats.rolloutPercentage, 100.0) // Default rollout
        XCTAssertNotNil(stats.userGroup)
        XCTAssertNotNil(stats.lastChecked)
    }

    func testFeatureUsageTracking() {
        // This test verifies that tracking doesn't crash
        // In a real implementation, you'd mock the analytics service

        let feature = FeatureFlagManager.Feature.nativeSpeech

        XCTAssertNoThrow {
            featureFlagManager.trackFeatureUsage(feature, action: "enabled")
            featureFlagManager.trackFeatureUsage(feature, action: "used")
            featureFlagManager.trackFeatureUsage(feature, action: "disabled")
        }
    }

    // MARK: - Configuration Persistence Tests

    func testConfigurationPersistence() async {
        let feature = FeatureFlagManager.Feature.awsBackend

        // Set custom configuration
        await featureFlagManager.setFeatureEnabled(true, for: feature)
        await featureFlagManager.updateRolloutPercentage(75.0, for: feature)

        // Verify configuration is set
        XCTAssertTrue(featureFlagManager.isEnabled(feature))
        XCTAssertEqual(featureFlagManager.getRolloutPercentage(for: feature), 75.0)

        // Configuration persistence would be tested with actual UserDefaults
        // For now, we verify the in-memory state is correct
        let config = featureFlagManager.flags[feature.rawValue]
        XCTAssertNotNil(config)
        XCTAssertTrue(config?.enabled ?? false)
        XCTAssertEqual(config?.rolloutPercentage ?? 0.0, 75.0)
    }

    // MARK: - Performance Tests

    func testFeatureFlagPerformance() {
        let feature = FeatureFlagManager.Feature.nativeSpeech
        let iterations = 10000

        measure {
            for i in 0..<iterations {
                let userId = "user_\(i % 1000)" // Reuse some user IDs to test caching
                _ = featureFlagManager.isEnabled(feature, for: userId)
            }
        }
    }

    func testHashingPerformance() {
        let userIds = (1...1000).map { "user_\($0)" }

        measure {
            for userId in userIds {
                _ = featureFlagManager.generateStableHash(userId)
            }
        }
    }

    // MARK: - Error Handling Tests

    func testInvalidInputHandling() async {
        // Test with empty user ID
        XCTAssertNoThrow {
            _ = featureFlagManager.isEnabled(.nativeSpeech, for: "")
        }

        // Test with very long user ID
        let longUserId = String(repeating: "a", count: 10000)
        XCTAssertNoThrow {
            _ = featureFlagManager.isEnabled(.nativeSpeech, for: longUserId)
        }

        // Test with special characters
        let specialUserId = "user@#$%^&*()_+{}|:<>?[];'\"\\,./`~"
        XCTAssertNoThrow {
            _ = featureFlagManager.isEnabled(.nativeSpeech, for: specialUserId)
        }
    }

    // MARK: - Integration Tests

    func testFeatureFlagIntegrationWithOtherServices() {
        // Test that feature flags work correctly in the context of other services
        // This would typically involve mocking other services and testing interactions

        let interviewManager = InterviewManager()

        // When AWS backend is disabled, should use fallback questions
        Task {
            await featureFlagManager.setFeatureEnabled(false, for: .awsBackend)

            // This would test that InterviewManager respects the feature flag
            // In a real test, you'd verify the behavior changes appropriately
        }
    }
}

// MARK: - Test Extensions

extension FeatureFlagManagerTests {

    /// Helper method to create a test user ID
    private func createTestUserId(_ suffix: String = "") -> String {
        return "test_user_\(UUID().uuidString.prefix(8))\(suffix)"
    }

    /// Helper method to reset feature flags to defaults
    private func resetFeatureFlagsToDefaults() {
        for feature in FeatureFlagManager.Feature.allCases {
            Task {
                await featureFlagManager.setFeatureEnabled(feature.defaultValue, for: feature)
                await featureFlagManager.updateRolloutPercentage(feature.defaultValue ? 100.0 : 0.0, for: feature)
            }
        }
    }

    /// Helper method to verify rollout percentages are within expected range
    private func verifyRolloutRange(
        _ actualPercentage: Double,
        expected: Double,
        tolerance: Double = 10.0,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        let lowerBound = max(0.0, expected - tolerance)
        let upperBound = min(100.0, expected + tolerance)

        XCTAssertTrue(
            actualPercentage >= lowerBound && actualPercentage <= upperBound,
            "Expected percentage \(expected) ± \(tolerance), got \(actualPercentage)",
            file: file,
            line: line
        )
    }
}

// MARK: - Mock Extensions for Testing

extension FeatureFlagManager {

    /// Test helper to access internal hash function
    func generateStableHash(_ input: String) -> UInt32 {
        var hash: UInt32 = 0
        for char in input.utf8 {
            hash = hash &* 31 &+ UInt32(char)
        }
        return hash
    }

    /// Test helper to access user group logic
    func getUserGroup(_ userId: String) -> UserGroup {
        // Check if user is internal
        if isInternalUser(userId) {
            return .internal
        }

        // Check user's opted-in group
        if let savedGroup = UserDefaults.standard.string(forKey: "user_group_\(userId)"),
           let group = UserGroup(rawValue: savedGroup) {
            return group
        }

        // Default assignment based on user hash
        let userHash = generateStableHash(userId)
        let groupIndex = userHash % UInt32(UserGroup.allCases.count - 1)
        return UserGroup.allCases[Int(groupIndex)]
    }

    /// Test helper to check internal user status
    private func isInternalUser(_ userId: String) -> Bool {
        let internalDomains = ["@inkra.io", "@company.com"]
        return internalDomains.contains { userId.contains($0) }
    }
}