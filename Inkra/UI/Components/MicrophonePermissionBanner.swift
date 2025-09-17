import SwiftUI
import AVFoundation

// CRITICAL: DO NOT revert deprecated API fixes in this file
// Using .denied directly causes build errors in iOS 17.0+
struct MicrophonePermissionBanner: View {
    @StateObject private var permissionManager = MicrophonePermissionManager.shared
    @State private var showPermissionSheet = false
    
    var body: some View {
        if permissionManager.needsPermission {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Image(systemName: "mic.slash.fill")
                        .font(.title3)
                        .foregroundColor(.red)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Microphone Access Required")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Text("Enable microphone access to use voice features")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Button("Enable") {
                        if permissionManager.permissionStatus == AVAudioSession.RecordPermission.denied {
                            permissionManager.openSettings()
                        } else {
                            showPermissionSheet = true
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
                .padding()
                .background(Color.red.opacity(0.1))
                .overlay(
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(Color.red.opacity(0.3)),
                    alignment: .bottom
                )
            }
            .sheet(isPresented: $showPermissionSheet) {
                MicrophonePermissionView {
                    showPermissionSheet = false
                }
                .modifier(PresentationDetentsModifier())
            }
        }
    }
}

struct PresentationDetentsModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 16.0, *) {
            content
                .presentationDetents([.medium])
        } else {
            content
        }
    }
}

#Preview {
    MicrophonePermissionBanner()
}