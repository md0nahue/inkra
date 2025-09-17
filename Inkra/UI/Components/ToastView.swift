import SwiftUI

@available(iOS 15.0, macOS 11.0, *)
struct ToastView: View {
    let message: String
    let isVisible: Bool
    
    var body: some View {
        if isVisible {
            Text(message)
                .font(.subheadline)
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.black.opacity(0.8))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
                .shadow(radius: 8)
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.8).combined(with: .opacity),
                    removal: .opacity
                ))
                .zIndex(999)
        }
    }
}

@available(iOS 15.0, macOS 11.0, *)
struct ToastModifier: ViewModifier {
    @Binding var isPresented: Bool
    let message: String
    let duration: TimeInterval
    
    func body(content: Content) -> some View {
        ZStack {
            content
            
            VStack {
                Spacer()
                
                ToastView(message: message, isVisible: isPresented)
                    .padding(.bottom, 100) // Above tab bar if present
                    .animation(.easeInOut(duration: 0.3), value: isPresented)
                
                Spacer()
            }
        }
        .onChange(of: isPresented) { newValue in
            if newValue {
                DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                    withAnimation {
                        isPresented = false
                    }
                }
            }
        }
    }
}

@available(iOS 15.0, macOS 11.0, *)
extension View {
    func toast(
        isPresented: Binding<Bool>,
        message: String,
        duration: TimeInterval = 3.0
    ) -> some View {
        modifier(ToastModifier(
            isPresented: isPresented,
            message: message,
            duration: duration
        ))
    }
}

struct ToastView_Previews: PreviewProvider {
    static var previews: some View {
        PreviewContainer()
    }
}

private struct PreviewContainer: View {
    @State var showToast = true
    
    var body: some View {
        VStack {
            Button("Show Toast") {
                showToast = true
            }
            
            Spacer()
        }
        .toast(isPresented: $showToast, message: "Your session has expired. Please log in again.")
        .padding()
    }
}