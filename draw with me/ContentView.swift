import SwiftUI

struct ContentView: View {
    @State private var animalInput = ""
    @State private var drawing: AnimalDrawing?
    @State private var stepIndex = 0
    
    // Voice control
    @StateObject private var voiceManager = VoiceManager()
    @StateObject private var audioFeedback = AudioFeedback()
    @State private var showWakeWordConfirmation = false
    
    var body: some View {
        NavigationView {
            ZStack {
                if let drawing = drawing {
                    // Drawing View
                    VStack(spacing: 16) {
                        Text("Drawing: \(drawing.name.capitalized)")
                            .font(.title2).bold()

                        PixelCanvas(
                            shapes: drawing.steps
                                .prefix(stepIndex + 1)
                                .flatMap { $0.shapes }
                        )
                        .frame(width: 300, height: 300)
                        .background(Color(UIColor.systemBackground))
                        .border(Color.gray)

                        // Step instruction with audio button
                        HStack {
                            Text(drawing.steps[stepIndex].instruction)
                                .font(.headline)
                                .multilineTextAlignment(.center)
                            
                            Button(action: {
                                audioFeedback.speak(drawing.steps[stepIndex].instruction)
                            }) {
                                Image(systemName: "speaker.wave.2.fill")
                                    .foregroundColor(.blue)
                            }
                        }
                        .padding(.horizontal)

                        // Navigation controls
                        HStack {
                            Button("Back") {
                                goToPreviousStep()
                            }
                            .disabled(stepIndex == 0)

                            Spacer()
                            
                            // Push-to-talk button
                            VoiceControlButton(isListening: $voiceManager.isListening) {
                                if voiceManager.isListening {
                                    voiceManager.stopListening()
                                } else {
                                    voiceManager.startListening()
                                }
                            }
                            
                            Spacer()

                            Button(stepIndex < drawing.steps.count - 1 ? "Next" : "Done") {
                                if stepIndex < drawing.steps.count - 1 {
                                    goToNextStep()
                                } else {
                                    reset()
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding()
                    .toolbar(.hidden, for: .navigationBar)

                } else {
                    // Home View
                    VStack(spacing: 20) {
                        Text("What animal do you want to draw?")
                            .font(.title2)

                        TextField("Type an animal name...", text: $animalInput)
                            .textFieldStyle(.roundedBorder)
                            .padding(.horizontal)

                        Button("Start Drawing") {
                            loadDrawing(for: animalInput.lowercased())
                        }
                        .disabled(animalInput.trimmingCharacters(in: .whitespaces).isEmpty)
                        
                        Text("OR")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        // Push-to-talk for voice input
                        VStack(spacing: 8) {
                            VoiceControlButton(isListening: $voiceManager.isListening) {
                                if voiceManager.isListening {
                                    voiceManager.stopListening()
                                } else {
                                    voiceManager.startListening()
                                }
                            }
                            
                            Text("Hold to speak")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        
                        if !voiceManager.recognizedText.isEmpty {
                            Text("Heard: \"\(voiceManager.recognizedText)\"")
                                .font(.caption)
                                .foregroundColor(.blue)
                                .padding(.horizontal)
                        }
                    }
                    .padding()
                    .navigationTitle("Draw With Me")
                }
                
                // Wake word confirmation overlay
                if showWakeWordConfirmation {
                    WakeWordConfirmation()
                        .transition(.scale.combined(with: .opacity))
                        .zIndex(1)
                }
                
                // Voice listening indicator
                if voiceManager.isListening {
                    VoiceListeningIndicator()
                        .transition(.scale.combined(with: .opacity))
                        .zIndex(2)
                }
            }
        }
        .onChange(of: voiceManager.currentCommand) { command in
            handleVoiceCommand(command)
        }
        .onChange(of: voiceManager.wakeWordDetected) { detected in
            if detected {
                showWakeWordConfirmation = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    showWakeWordConfirmation = false
                    voiceManager.wakeWordDetected = false
                }
            }
        }
    }
    
    // MARK: - Voice Command Handling
    private func handleVoiceCommand(_ command: VoiceManager.Command?) {
        guard let command = command else { return }
        
        switch command {
        case .drawAnimal(let animal):
            if drawing == nil {
                loadDrawing(for: animal)
                audioFeedback.confirmCommand(animal)
            }
            
        case .next:
            if drawing != nil {
                goToNextStep()
            }
            
        case .back:
            if drawing != nil {
                goToPreviousStep()
            }
            
        case .done:
            reset()
        }
        
        // Clear the command after handling
        voiceManager.currentCommand = nil
    }
    
    // MARK: - Navigation Functions
    private func goToNextStep() {
        if let drawing = drawing, stepIndex < drawing.steps.count - 1 {
            stepIndex += 1
            audioFeedback.announceStep(drawing.steps[stepIndex].instruction)
        }
    }
    
    private func goToPreviousStep() {
        if stepIndex > 0 {
            stepIndex -= 1
            if let drawing = drawing {
                audioFeedback.announceStep(drawing.steps[stepIndex].instruction)
            }
        }
    }
    
    private func loadDrawing(for animal: String) {
        if let animalDrawing = AnimalDatabase.shared.getAnimal(named: animal) {
            drawing = animalDrawing
            stepIndex = 0
            audioFeedback.announceStep(animalDrawing.steps[0].instruction)
        } else {
            // Offline fallback - suggest available animals
            let available = AnimalDatabase.shared.getAllAnimalNames()
            audioFeedback.speak("I don't know how to draw \(animal) yet. Try: \(available.prefix(3).joined(separator: ", "))")
        }
    }

    private func reset() {
        drawing = nil
        animalInput = ""
        stepIndex = 0
        audioFeedback.speak("Great job! What should we draw next?")
    }
}

// MARK: - Voice UI Components
struct VoiceControlButton: View {
    @Binding var isListening: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(isListening ? Color.red : Color.blue)
                    .frame(width: 60, height: 60)
                
                Image(systemName: isListening ? "mic.fill" : "mic")
                    .foregroundColor(.white)
                    .font(.title2)
            }
        }
        .scaleEffect(isListening ? 1.1 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isListening)
    }
}

struct VoiceListeningIndicator: View {
    @State private var animationAmount = 1.0
    
    var body: some View {
        VStack {
            Spacer()
            
            HStack(spacing: 4) {
                ForEach(0..<3) { i in
                    Rectangle()
                        .fill(Color.red)
                        .frame(width: 4, height: 20)
                        .scaleEffect(y: animationAmount)
                        .animation(
                            Animation.easeInOut(duration: 0.5)
                                .repeatForever()
                                .delay(Double(i) * 0.1),
                            value: animationAmount
                        )
                }
            }
            .padding()
            .background(Color.white.opacity(0.9))
            .cornerRadius(8)
            .shadow(radius: 4)
            .padding(.bottom, 100)
        }
        .onAppear {
            animationAmount = 1.5
        }
    }
}

struct WakeWordConfirmation: View {
    var body: some View {
        VStack {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 50))
                .foregroundColor(.green)
            
            Text("Ready to draw!")
                .font(.headline)
        }
        .padding()
        .background(Color.white.opacity(0.95))
        .cornerRadius(20)
        .shadow(radius: 10)
    }
}

// MARK: - Pixel Canvas (with dark mode support)
struct PixelCanvas: View {
    let shapes: [PixelShape]
    @Environment(\.colorScheme) var colorScheme  // Added for dark mode support

    var body: some View {
        GeometryReader { _ in
            Canvas { context, size in
                let scale = min(size.width, size.height) / 50
                
                // Use adaptive colors that work in both light and dark mode
                let drawingColor: Color = .primary

                // 1) Stroke head outline
                if let head = shapes.first {
                    var headPath = Path()
                    switch head {
                    case let .circle(center, r):
                        let cgCenter = center.cgPoint
                        let rect = CGRect(
                            x: (cgCenter.x - r) * scale,
                            y: (cgCenter.y - r) * scale,
                            width: r * 2 * scale,
                            height: r * 2 * scale
                        )
                        headPath.addEllipse(in: rect)
                    case let .ellipse(center, rx, ry):
                        let cgCenter = center.cgPoint
                        let rect = CGRect(
                            x: (cgCenter.x - rx) * scale,
                            y: (cgCenter.y - ry) * scale,
                            width: rx * 2 * scale,
                            height: ry * 2 * scale
                        )
                        headPath.addEllipse(in: rect)
                    default:
                        break
                    }
                    context.stroke(headPath, with: .color(drawingColor), lineWidth: max(1, scale))
                }

                // 2) Draw all other shapes
                for shape in shapes.dropFirst() {
                    var path = Path()
                    switch shape {
                    case let .circle(center, r):
                        let cgCenter = center.cgPoint
                        let rect = CGRect(
                            x: (cgCenter.x - r) * scale,
                            y: (cgCenter.y - r) * scale,
                            width: r * 2 * scale,
                            height: r * 2 * scale
                        )
                        path.addEllipse(in: rect)

                    case let .ellipse(center, rx, ry):
                        let cgCenter = center.cgPoint
                        let rect = CGRect(
                            x: (cgCenter.x - rx) * scale,
                            y: (cgCenter.y - ry) * scale,
                            width: rx * 2 * scale,
                            height: ry * 2 * scale
                        )
                        path.addEllipse(in: rect)

                    case let .square(origin, side):
                        let cgOrigin = origin.cgPoint
                        path.addRect(CGRect(
                            x: cgOrigin.x * scale,
                            y: cgOrigin.y * scale,
                            width: side * scale,
                            height: side * scale
                        ))

                    case let .rectangle(origin, size):
                        let cgOrigin = origin.cgPoint
                        let cgSize = size.cgSize
                        path.addRect(CGRect(
                            x: cgOrigin.x * scale,
                            y: cgOrigin.y * scale,
                            width: cgSize.width * scale,
                            height: cgSize.height * scale
                        ))

                    case let .triangle(p1, p2, p3):
                        let cgP1 = p1.cgPoint
                        let cgP2 = p2.cgPoint
                        let cgP3 = p3.cgPoint
                        path.move(to: CGPoint(x: cgP1.x * scale, y: cgP1.y * scale))
                        path.addLine(to: CGPoint(x: cgP2.x * scale, y: cgP2.y * scale))
                        path.addLine(to: CGPoint(x: cgP3.x * scale, y: cgP3.y * scale))
                        path.closeSubpath()

                    case let .line(a, b):
                        let cgA = a.cgPoint
                        let cgB = b.cgPoint
                        path.move(to: CGPoint(x: cgA.x * scale, y: cgA.y * scale))
                        path.addLine(to: CGPoint(x: cgB.x * scale, y: cgB.y * scale))

                    case let .polyline(points):
                        if let first = points.first {
                            let cgFirst = first.cgPoint
                            path.move(to: CGPoint(x: cgFirst.x * scale, y: cgFirst.y * scale))
                            for p in points.dropFirst() {
                                let cgP = p.cgPoint
                                path.addLine(to: CGPoint(x: cgP.x * scale, y: cgP.y * scale))
                            }
                        }
                    }

                    // Stroke for ellipses/lines/polylines; fill everything else
                    switch shape {
                    case .ellipse, .line, .polyline:
                        context.stroke(path, with: .color(drawingColor), lineWidth: max(1, scale))
                    default:
                        context.fill(path, with: .color(drawingColor))
                    }
                }
            }
        }
    }
}

// MARK: - Preview
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ContentView()
                .preferredColorScheme(.light)
            ContentView()
                .preferredColorScheme(.dark)
        }
    }
}
