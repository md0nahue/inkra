import SwiftUI

struct DeviceToast: View {
    @ObservedObject var audioManager = AudioDeviceManager.shared
    let onTap: () -> Void
    
    var body: some View {
        if audioManager.showDeviceToast {
            VStack {
                Spacer()
                
                HStack {
                    Image(systemName: "headphones")
                        .foregroundColor(.white)
                        .font(.system(size: 16, weight: .medium))
                    
                    Text("Connected: \(audioManager.lastConnectedDevice)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.white.opacity(0.7))
                        .font(.system(size: 12, weight: .semibold))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.black.opacity(0.85))
                        .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                )
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
                .onTapGesture {
                    audioManager.dismissToast()
                    onTap()
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .bottom).combined(with: .opacity),
                    removal: .move(edge: .bottom).combined(with: .opacity)
                ))
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: audioManager.showDeviceToast)
            }
            .allowsHitTesting(true)
        }
    }
}

struct DeviceToastModifier: ViewModifier {
    @State private var showAudioSettings = false
    
    func body(content: Content) -> some View {
        ZStack {
            content
            
            DeviceToast {
                showAudioSettings = true
            }
        }
        .fullScreenCover(isPresented: $showAudioSettings) {
            AudioSettingsView()
        }
    }
}

extension View {
    func deviceToast() -> some View {
        modifier(DeviceToastModifier())
    }
}