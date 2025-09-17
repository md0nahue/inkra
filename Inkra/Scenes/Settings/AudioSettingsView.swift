import SwiftUI
import AVFoundation

struct AudioSettingsView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject private var audioManager = AudioDeviceManager.shared
    @State private var selectedInputId: String?
    @State private var useSpeaker = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Current Status Card
                    VStack(alignment: .leading, spacing: 16) {
                        Label("Current Audio Setup", systemImage: "waveform.circle.fill")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Input")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(audioManager.currentInput?.portName ?? "None")
                                    .font(.system(size: 14, weight: .medium))
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("Output")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(audioManager.currentOutput?.portName ?? "None")
                                    .font(.system(size: 14, weight: .medium))
                            }
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemGray6))
                    )
                    
                    // Input Selection
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Microphone", systemImage: "mic.fill")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        if audioManager.availableInputs.isEmpty {
                            HStack {
                                Image(systemName: "exclamationmark.circle")
                                    .foregroundColor(.orange)
                                Text("No microphones available")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color(.systemGray6))
                            )
                        } else {
                            ForEach(audioManager.availableInputs, id: \.uid) { input in
                                InputDeviceRow(
                                    device: input,
                                    isSelected: audioManager.currentInput?.uid == input.uid,
                                    onSelect: {
                                        audioManager.selectInput(input)
                                    }
                                )
                            }
                        }
                    }
                    
                    Divider()
                    
                    // Output Selection
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Speaker & Audio Output", systemImage: "speaker.wave.2.fill")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        // Speaker/Receiver toggle
                        HStack {
                            Image(systemName: useSpeaker ? "speaker.wave.3.fill" : "speaker.fill")
                                .foregroundColor(.blue)
                                .frame(width: 24)
                            
                            Text("Use Speaker")
                                .font(.system(size: 15))
                            
                            Spacer()
                            
                            Toggle("", isOn: $useSpeaker)
                                .labelsHidden()
                                .onChange(of: useSpeaker) { newValue in
                                    audioManager.selectOutput(useSpeaker: newValue)
                                }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color(.systemGray6))
                        )
                        
                        // Show current output route
                        if let output = audioManager.currentOutput {
                            OutputDeviceInfo(device: output)
                        }
                    }
                    
                    // Test Audio Section
                    VStack(spacing: 12) {
                        Button(action: testAudioPlayback) {
                            Label("Test Audio Output", systemImage: "play.circle.fill")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color.blue)
                                )
                                .foregroundColor(.white)
                        }
                        
                        Text("Tap to play a test sound through current output")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer(minLength: 20)
                }
                .padding()
            }
            .navigationTitle("Audio Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.system(size: 17, weight: .semibold))
                }
            }
        }
        .onAppear {
            // Set initial speaker state based on current output
            useSpeaker = audioManager.currentOutput?.portType == .builtInSpeaker
        }
    }
    
    private func testAudioPlayback() {
        // Play a system sound for testing
        AudioServicesPlaySystemSound(1000) // Standard system sound
    }
}

struct InputDeviceRow: View {
    let device: AVAudioSessionPortDescription
    let isSelected: Bool
    let onSelect: () -> Void
    
    private var deviceIcon: String {
        switch device.portType {
        case .builtInMic:
            return "mic.fill"
        case .headsetMic:
            return "headphones"
        case .bluetoothHFP:
            return "airpodspro"
        case .usbAudio:
            return "cable.connector"
        default:
            return "mic.fill"
        }
    }
    
    var body: some View {
        Button(action: onSelect) {
            HStack {
                Image(systemName: deviceIcon)
                    .foregroundColor(isSelected ? .blue : .gray)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(device.portName)
                        .font(.system(size: 15, weight: isSelected ? .semibold : .regular))
                        .foregroundColor(.primary)
                    
                    if let dataSources = device.dataSources, !dataSources.isEmpty {
                        Text(dataSources.first?.dataSourceName ?? "")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? Color.blue.opacity(0.1) : Color(.systemGray6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct OutputDeviceInfo: View {
    let device: AVAudioSessionPortDescription
    
    private var deviceIcon: String {
        switch device.portType {
        case .builtInSpeaker:
            return "speaker.wave.3.fill"
        case .headphones:
            return "headphones"
        case .bluetoothA2DP, .bluetoothLE:
            return "airpodspro"
        case .airPlay:
            return "airplayaudio"
        case .builtInReceiver:
            return "phone.fill"
        default:
            return "speaker.fill"
        }
    }
    
    var body: some View {
        HStack {
            Image(systemName: deviceIcon)
                .foregroundColor(.blue)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Current Output")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(device.portName)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.primary)
            }
            
            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.systemGray6))
        )
    }
}