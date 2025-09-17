

**PARALLEL BUILD MANAGEMENT:**
- Each Claude process gets unique build folder: `build_claude_$(date +%s)_$$`
- Builds older than 1 hour are auto-cleaned to prevent disk bloat
- This prevents parallel Claude processes from interfering with each other

**MANDATORY Test Suite (ALWAYS RUN BEFORE COMMITS):**
```bash
# Set up unique build directory for this Claude session
export BUILD_DIR="build_claude_$(date +%s)_$$"
export DERIVED_DATA_PATH="/tmp/inkra_builds/$BUILD_DIR"

# Clean up old builds (older than 1 hour)
find /tmp/inkra_builds -name "build_claude_*" -type d -mmin +60 -exec rm -rf {} + 2>/dev/null || true

# Create our build directory
mkdir -p "$DERIVED_DATA_PATH"

# Build for testing with isolated build directory
xcodebuild build-for-testing \
  -project Inkra.xcodeproj \
  -scheme Inkra \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -derivedDataPath "$DERIVED_DATA_PATH"

# CORE WORKFLOW TESTS - Must Pass 100%
xcodebuild test \
  -project Inkra.xcodeproj \
  -scheme Inkra \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  -only-testing:InkraTests/CoreWorkflowTests &

xcodebuild test \
  -project Inkra.xcodeproj \
  -scheme Inkra \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  -only-testing:InkraTests/InterviewEngineTests &

xcodebuild test \
  -project Inkra.xcodeproj \
  -scheme Inkra \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  -only-testing:InkraTests/AudioRecordingPathTests &
wait

# RELIABILITY & PERFORMANCE TESTS - Must Pass 95%+
xcodebuild test \
  -project Inkra.xcodeproj \
  -scheme Inkra \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  -only-testing:InkraTests/ExportServiceTests &

xcodebuild test \
  -project Inkra.xcodeproj \
  -scheme Inkra \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  -only-testing:InkraTests/QuoteShotServiceTests &
wait

# UI WORKFLOW VALIDATION - Must Pass Before ANY UI Changes
xcodebuild test \
  -project Inkra.xcodeproj \
  -scheme Inkra \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  -only-testing:InkraUITests/CoreWorkflowUITests

# Clean up this build after successful completion
rm -rf "$DERIVED_DATA_PATH"
```

**PARALLEL-SAFE BUILD SCRIPT:**
```bash
#!/bin/bash
# build_and_test.sh - Parallel-safe build script

set -e

# Generate unique build identifier
BUILD_ID="claude_$(date +%s)_$$"
DERIVED_DATA_PATH="/tmp/inkra_builds/$BUILD_ID"
CLEANUP_LOCK="/tmp/inkra_build_cleanup.lock"

echo "🏗️ Starting build with ID: $BUILD_ID"

# Cleanup function
cleanup() {
    echo "🧹 Cleaning up build directory: $DERIVED_DATA_PATH"
    rm -rf "$DERIVED_DATA_PATH"
}

# Set up cleanup on exit
trap cleanup EXIT

# Create build directory
mkdir -p "$DERIVED_DATA_PATH"

# Clean old builds (with lock to prevent race conditions)
(
    flock -n 200 || exit 0
    echo "🗑️ Cleaning builds older than 1 hour..."
    find /tmp/inkra_builds -name "claude_*" -type d -mmin +60 -exec rm -rf {} + 2>/dev/null || true
) 200>"$CLEANUP_LOCK"

# Run the actual build and tests
exec "$@" -derivedDataPath "$DERIVED_DATA_PATH"
```

**HUMAN INTERVENTION REQUESTS:**
When you encounter situations that require human intervention, create/update the `need-human.md` file with your request. **NEVER overwrite this file** - always append to it to preserve previous requests.

Examples of when to request human intervention:
- AWS permissions or IAM role changes needed
- Cloud services configuration (Lambda, S3, RDS, etc.)
- App Store Connect or TestFlight setup
- Certificates, provisioning profiles, or signing issues
- External API keys or secrets management
- Production environment debugging
- Performance profiling on physical devices
- Third-party service integrations
- Network infrastructure or CDN configuration
- Database migrations or schema changes

Format for need-human.md entries:
```
## [Date] - [Brief Title]
**Priority:** [Low/Medium/High/Critical]
**Category:** [AWS/Infrastructure/Security/etc.]
**Description:** [Detailed explanation]
**Context:** [What you were working on]
**Reason:** [Why human intervention is needed]
**Suggested Actions:** [What the human should check/do]
---
```