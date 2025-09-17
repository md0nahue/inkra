import SwiftUI

@available(iOS 15.0, macOS 11.0, *)
struct AudioVisualizer: View {
    @State private var drawingHeight = true
    
    // Control how animated the visualizer looks
    let barCount: Int
    let totalHeight: CGFloat
    let totalWidth: CGFloat
    let barColor: Color
    let isAnimating: Bool
    
    // Different animation states for different contexts
    enum VisualizerState {
        case idle
        case listening
        case speaking
        case processing
    }
    
    let state: VisualizerState
    
    init(
        state: VisualizerState = .listening,
        barCount: Int = 5,
        totalHeight: CGFloat = 64,
        totalWidth: CGFloat = 80,
        barColor: Color = ColorTheme.primaryAccent,
        isAnimating: Bool = true
    ) {
        self.state = state
        self.barCount = barCount
        self.totalHeight = totalHeight
        self.totalWidth = totalWidth
        self.barColor = barColor
        self.isAnimating = isAnimating
    }
    
    var animation: Animation {
        switch state {
        case .idle:
            return .linear(duration: 1.5).repeatForever()
        case .listening:
            return .linear(duration: 0.5).repeatForever()
        case .speaking:
            return .linear(duration: 0.3).repeatForever()
        case .processing:
            return .linear(duration: 0.8).repeatForever()
        }
    }
    
    var body: some View {
        HStack(spacing: totalWidth / CGFloat(barCount * 2)) {
            ForEach(0..<barCount, id: \.self) { index in
                bar(
                    low: lowValueForState(index: index),
                    high: highValueForState(index: index)
                )
                .animation(
                    animation.speed(speedForBar(index: index)),
                    value: drawingHeight
                )
            }
        }
        .frame(width: totalWidth)
        .onAppear {
            if isAnimating {
                drawingHeight.toggle()
            }
        }
        .onChange(of: isAnimating) { newValue in
            if newValue {
                drawingHeight.toggle()
            }
        }
        .onChange(of: state) { newState in
            // Restart animation when state changes
            if isAnimating {
                drawingHeight.toggle()
            }
        }
    }
    
    func bar(low: CGFloat = 0.0, high: CGFloat = 1.0) -> some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(
                LinearGradient(
                    gradient: Gradient(colors: [
                        barColor,
                        barColor.opacity(0.7)
                    ]),
                    startPoint: .bottom,
                    endPoint: .top
                )
            )
            .frame(height: (drawingHeight ? high : low) * totalHeight)
            .frame(height: totalHeight, alignment: .bottom)
            .shadow(color: barColor.opacity(0.3), radius: 2, x: 0, y: 0)
    }
    
    // State-specific low values for each bar
    private func lowValueForState(index: Int) -> CGFloat {
        switch state {
        case .idle:
            return [0.1, 0.05, 0.1, 0.05, 0.1][index % 5]
        case .listening:
            return [0.4, 0.3, 0.5, 0.3, 0.5][index % 5]
        case .speaking:
            return [0.6, 0.4, 0.7, 0.5, 0.6][index % 5]
        case .processing:
            return [0.2, 0.15, 0.25, 0.15, 0.2][index % 5]
        }
    }
    
    // State-specific high values for each bar  
    private func highValueForState(index: Int) -> CGFloat {
        switch state {
        case .idle:
            return [0.3, 0.2, 0.35, 0.25, 0.3][index % 5]
        case .listening:
            return [0.9, 0.7, 1.0, 0.8, 0.95][index % 5]
        case .speaking:
            return [1.0, 0.8, 1.0, 0.9, 1.0][index % 5]
        case .processing:
            return [0.5, 0.4, 0.6, 0.45, 0.55][index % 5]
        }
    }
    
    // Different animation speeds for each bar to create organic feel
    private func speedForBar(index: Int) -> Double {
        switch state {
        case .idle:
            return [0.8, 0.6, 1.0, 0.7, 0.9][index % 5]
        case .listening:
            return [1.5, 1.2, 1.0, 1.7, 1.0][index % 5]
        case .speaking:
            return [2.0, 1.8, 1.5, 2.2, 1.9][index % 5]
        case .processing:
            return [1.1, 0.9, 1.3, 1.0, 1.2][index % 5]
        }
    }
}


#Preview {
    VStack(spacing: 40) {
        Text("Bar Visualizers")
            .font(.headline)
        
        HStack(spacing: 20) {
            VStack {
                AudioVisualizer(state: .idle)
                Text("Idle")
            }
            
            VStack {
                AudioVisualizer(state: .listening)
                Text("Listening")
            }
            
            VStack {
                AudioVisualizer(state: .speaking, barColor: .orange)
                Text("Speaking")
            }
        }
        
        Text("Circular Visualizers")
            .font(.headline)
        
        HStack(spacing: 30) {
            VStack {
                TalkingIndicator(state: .listening, size: 80)
                Text("Listening")
            }
            
            VStack {
                TalkingIndicator(state: .speaking, size: 80)
                Text("Speaking")
            }
            
            VStack {
                TalkingIndicator(state: .idle, size: 80)
                Text("Idle")
            }
        }
    }
    .padding()
    .background(Color.black)
}