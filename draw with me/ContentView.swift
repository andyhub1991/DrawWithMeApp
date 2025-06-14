import SwiftUI

// MARK: - App State Management
enum AppState: Equatable {
    case animalSelection
    case drawing(AnimalDrawing, stepIndex: Int)
    case completed(AnimalDrawing)
    
    static func == (lhs: AppState, rhs: AppState) -> Bool {
        switch (lhs, rhs) {
        case (.animalSelection, .animalSelection):
            return true
        case let (.drawing(animal1, step1), .drawing(animal2, step2)):
            return animal1.name == animal2.name && step1 == step2
        case let (.completed(animal1), .completed(animal2)):
            return animal1.name == animal2.name
        default:
            return false
        }
    }
}

struct ContentView: View {
    @State private var appState: AppState = .animalSelection
    @State private var selectedAnimal: String = ""
    @State private var animationScale: CGFloat = 1.0
    
    var body: some View {
        NavigationView {
            ZStack {
                // Colorful gradient background
                LinearGradient(
                    colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.1)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                // Main content
                Group {
                    switch appState {
                    case .animalSelection:
                        AnimalSelectionView(
                            onAnimalSelected: handleAnimalSelection,
                            onTextInputRequested: { }  // No longer used
                        )
                        
                    case .drawing(let animal, let stepIndex):
                        DrawingView(
                            animal: animal,
                            stepIndex: stepIndex,
                            onNext: { handleNextStep(animal: animal, currentStep: stepIndex) },
                            onBack: { handlePreviousStep(animal: animal, currentStep: stepIndex) },
                            onHome: { appState = .animalSelection }
                        )
                        
                    case .completed(let animal):
                        CompletionView(
                            animal: animal,
                            onNewDrawing: { appState = .animalSelection },
                            onRedraw: { appState = .drawing(animal, stepIndex: 0) }
                        )
                    }
                }
                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: appState)
            }
            .navigationBarHidden(true)
        }
    }
    
    // MARK: - Handlers
    private func handleAnimalSelection(_ animalName: String) {
        switch AnimalDatabase.shared.findBestMatch(for: animalName) {
        case .exact(let animal):
            withAnimation(.spring()) {
                appState = .drawing(animal, stepIndex: 0)
            }
            
        case .suggestion(let suggestedName):
            // For simplicity, just use the suggestion
            if let animal = AnimalDatabase.shared.getAnimal(named: suggestedName) {
                withAnimation(.spring()) {
                    appState = .drawing(animal, stepIndex: 0)
                }
            }
            
        case .random(let randomAnimals):
            // Pick the first suggestion
            if let firstAnimal = randomAnimals.first {
                withAnimation(.spring()) {
                    appState = .drawing(firstAnimal, stepIndex: 0)
                }
            }
        }
    }
    
    private func handleNextStep(animal: AnimalDrawing, currentStep: Int) {
        let nextStep = currentStep + 1
        if nextStep < animal.steps.count {
            withAnimation(.spring()) {
                appState = .drawing(animal, stepIndex: nextStep)
            }
        } else {
            withAnimation(.spring()) {
                appState = .completed(animal)
            }
        }
    }
    
    private func handlePreviousStep(animal: AnimalDrawing, currentStep: Int) {
        if currentStep > 0 {
            withAnimation(.spring()) {
                appState = .drawing(animal, stepIndex: currentStep - 1)
            }
        }
    }
}

// MARK: - Animal Selection View
struct AnimalSelectionView: View {
    let onAnimalSelected: (String) -> Void
    let onTextInputRequested: () -> Void
    
    // All animal emojis mapping
    let animalEmojiMap: [String: String] = [
        "cat": "🐱", "dog": "🐶", "panda": "🐼", "frog": "🐸",
        "rabbit": "🐰", "pig": "🐷", "lion": "🦁", "monkey": "🐵",
        "bear": "🐻", "owl": "🦉", "horse": "🐴", "elephant": "🐘",
        "sheep": "🐑", "mouse": "🐭", "tiger": "🐅", "cow": "🐄",
        "chicken": "🐓", "duck": "🦆", "fish": "🐟", "turtle": "🐢",
        "penguin": "🐧", "seal": "🦭", "whale": "🐋", "fox": "🦊"
    ]
    
    let animalColorMap: [String: Color] = [
        "cat": .orange, "dog": .brown, "panda": .gray, "frog": .green,
        "rabbit": .pink, "pig": .pink, "lion": .yellow, "monkey": .brown,
        "bear": .brown, "owl": .gray, "horse": .brown, "elephant": .gray,
        "sheep": .gray, "mouse": .gray, "tiger": .orange, "cow": .brown,
        "chicken": .yellow, "duck": .yellow, "fish": .blue, "turtle": .green,
        "penguin": .blue, "seal": .gray, "whale": .blue, "fox": .orange
    ]
    
    @State private var animatingIndices: Set<Int> = []
    @State private var showAllAnimals = false
    @State private var shuffledAnimals: [String] = []
    
    var displayedAnimals: [String] {
        showAllAnimals ? shuffledAnimals : Array(shuffledAnimals.prefix(12))
    }
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 20) {
                    titleSection
                        .id("top")
                    animalGrid
                    loadMoreButton
                    
                    if showAllAnimals {
                        HStack {
                            Text("\(shuffledAnimals.count) animals available")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundColor(.gray)
                            
                            Button(action: {
                                loadAndShuffleAnimals()
                                withAnimation {
                                    proxy.scrollTo("top", anchor: .top)
                                }
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "shuffle")
                                        .font(.system(size: 12))
                                    Text("Shuffle")
                                        .font(.system(size: 14, weight: .medium, design: .rounded))
                                }
                                .foregroundColor(.blue)
                            }
                        }
                        .padding(.bottom, 20)
                    }
                    
                    Spacer(minLength: 50)
                }
            }
            .onAppear {
                loadAndShuffleAnimals()
            }
        }
    }
    
    private func loadAndShuffleAnimals() {
        // Get all animals from the database and shuffle them
        let allAnimals = AnimalDatabase.shared.getAllAnimalNames()
        shuffledAnimals = allAnimals.shuffled()
        // Reset animation states for new display
        animatingIndices.removeAll()
    }
    
    private var titleSection: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                Text("🎨")
                    .font(.system(size: 60))
                    .rotationEffect(.degrees(-15))
                
                Text("✏️")
                    .font(.system(size: 50))
                    .rotationEffect(.degrees(15))
            }
            
            Text("What shall we draw?")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
            
            Text("Choose an animal to start!")
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundColor(.secondary)
        }
        .padding(.top, 40)
    }
    
    private var animalGrid: some View {
        let columns = [
            GridItem(.flexible(), spacing: 16),
            GridItem(.flexible(), spacing: 16),
            GridItem(.flexible(), spacing: 16)
        ]
        
        return LazyVGrid(columns: columns, spacing: 16) {
            ForEach(0..<displayedAnimals.count, id: \.self) { index in
                if index < displayedAnimals.count {
                    makeAnimalButton(at: index)
                }
            }
        }
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private func makeAnimalButton(at index: Int) -> some View {
        let animalName = displayedAnimals[index]
        let emoji = animalEmojiMap[animalName] ?? getDefaultEmoji(for: animalName)
        let color = animalColorMap[animalName] ?? getDefaultColor(for: animalName)
        
        AnimalButton(
            emoji: emoji,
            name: animalName,
            color: color,
            isAnimating: animatingIndices.contains(index)
        ) {
            onAnimalSelected(animalName)
        }
        .onAppear {
            withAnimation(.spring().delay(Double(index % 12) * 0.1)) {
                _ = animatingIndices.insert(index)
            }
        }
    }
    
    private func getDefaultEmoji(for animal: String) -> String {
        // Default emojis for animals not in the map
        switch animal {
        case let name where name.contains("bird"): return "🐦"
        case let name where name.contains("cat"): return "🐱"
        case let name where name.contains("dog"): return "🐶"
        default: return "🐾"
        }
    }
    
    private func getDefaultColor(for animal: String) -> Color {
        // Generate a consistent color based on the animal name
        let hash = animal.hashValue
        let hue = Double(abs(hash) % 360) / 360.0
        return Color(hue: hue, saturation: 0.5, brightness: 0.8)
    }
    
    private var loadMoreButton: some View {
        Button(action: {
            withAnimation(.spring()) {
                showAllAnimals.toggle()
                if showAllAnimals {
                    // Trigger animations for newly visible animals
                    for i in 12..<min(shuffledAnimals.count, 24) {
                        DispatchQueue.main.asyncAfter(deadline: .now() + Double(i - 12) * 0.05) {
                            _ = animatingIndices.insert(i)
                        }
                    }
                }
            }
        }) {
            HStack {
                Image(systemName: showAllAnimals ? "chevron.up.circle" : "plus.circle")
                    .font(.title2)
                    .animation(.spring(), value: showAllAnimals)
                Text(showAllAnimals ? "Show Less" : "Load More Animals")
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 30)
            .padding(.vertical, 15)
            .background(
                RoundedRectangle(cornerRadius: 25)
                    .fill(LinearGradient(
                        colors: showAllAnimals ? [Color.gray, Color.gray.opacity(0.8)] : [Color.purple, Color.blue],
                        startPoint: .leading,
                        endPoint: .trailing
                    ))
            )
            .shadow(radius: 5)
        }
        .padding(.top, 20)
    }
}

// MARK: - Animal Button Component
struct AnimalButton: View {
    let emoji: String
    let name: String
    let color: Color
    let isAnimating: Bool
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            isPressed = true
            
            // Haptic feedback
            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.impactOccurred()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isPressed = false
                action()
            }
        }) {
            VStack(spacing: 8) {
                Text(emoji)
                    .font(.system(size: 50))
                    .scaleEffect(isPressed ? 1.3 : 1.0)
                
                Text(name)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(.primary)
            }
            .frame(width: 100, height: 100)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(color.opacity(0.2))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(color, lineWidth: 3)
                    )
            )
            .scaleEffect(isAnimating ? 1.0 : 0.8)
            .opacity(isAnimating ? 1.0 : 0.0)
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        }
    }
}

// MARK: - Drawing View
struct DrawingView: View {
    let animal: AnimalDrawing
    let stepIndex: Int
    let onNext: () -> Void
    let onBack: () -> Void
    let onHome: () -> Void
    
    @State private var showCanvas = false
    @State private var stepTextVisible = false
    
    var body: some View {
        VStack(spacing: 20) {
            // Top bar
            HStack {
                // Home button
                Button(action: onHome) {
                    Image(systemName: "house.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                        .frame(width: 50, height: 50)
                        .background(Circle().fill(Color.purple))
                        .shadow(radius: 3)
                }
                
                Spacer()
                
                // Progress
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Step \(stepIndex + 1) of \(animal.steps.count)")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(.gray)
                    
                    ProgressView(value: Double(stepIndex + 1), total: Double(animal.steps.count))
                        .frame(width: 150)
                        .tint(.green)
                }
            }
            .padding(.horizontal)
            
            // Canvas with animation
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
                    .shadow(radius: 10)
                
                if showCanvas {
                    PixelCanvas(
                        shapes: animal.steps
                            .prefix(stepIndex + 1)
                            .flatMap { $0.shapes },
                        animalName: animal.name
                    )
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .frame(width: 350, height: 350)
            .onAppear {
                withAnimation(.spring().delay(0.2)) {
                    showCanvas = true
                }
            }
            
            // Instruction card
            VStack(spacing: 12) {
                if stepTextVisible {
                    Text(animal.steps[stepIndex].instruction)
                        .font(.system(size: 24, weight: .medium, design: .rounded))
                        .multilineTextAlignment(.center)
                        .foregroundColor(.primary)
                        .padding(.horizontal)
                        .transition(.asymmetric(
                            insertion: .scale.combined(with: .opacity),
                            removal: .scale.combined(with: .opacity)
                        ))
                }
            }
            .frame(minHeight: 80)
            .onAppear {
                withAnimation(.spring().delay(0.5)) {
                    stepTextVisible = true
                }
            }
            .onChange(of: stepIndex) { _, _ in
                stepTextVisible = false
                withAnimation(.spring().delay(0.2)) {
                    stepTextVisible = true
                }
            }
            
            // Navigation buttons
            HStack(spacing: 30) {
                // Back button
                NavigationButton(
                    icon: "arrow.left",
                    label: "Back",
                    color: .orange,
                    isEnabled: stepIndex > 0,
                    action: onBack
                )
                
                // Next button
                NavigationButton(
                    icon: "arrow.right",
                    label: stepIndex == animal.steps.count - 1 ? "Finish!" : "Next",
                    color: .green,
                    isEnabled: true,
                    isLarge: true,
                    action: onNext
                )
            }
            .padding(.horizontal, 40)
            
            Spacer()
        }
        .padding(.top, 40)
    }
}

// MARK: - Navigation Button
struct NavigationButton: View {
    let icon: String
    let label: String
    let color: Color
    let isEnabled: Bool
    let isLarge: Bool
    let action: () -> Void
    
    @State private var isPressed = false
    
    init(icon: String, label: String, color: Color, isEnabled: Bool = true, isLarge: Bool = false, action: @escaping () -> Void) {
        self.icon = icon
        self.label = label
        self.color = color
        self.isEnabled = isEnabled
        self.isLarge = isLarge
        self.action = action
    }
    
    var body: some View {
        Button(action: {
            guard isEnabled else { return }
            
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                isPressed = true
            }
            
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isPressed = false
                action()
            }
        }) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: isLarge ? 24 : 20, weight: .bold))
                
                Text(label)
                    .font(.system(size: isLarge ? 22 : 18, weight: .bold, design: .rounded))
            }
            .foregroundColor(.white)
            .padding(.horizontal, isLarge ? 40 : 25)
            .padding(.vertical, isLarge ? 18 : 14)
            .background(
                RoundedRectangle(cornerRadius: 25)
                    .fill(isEnabled ? color : Color.gray)
                    .shadow(radius: isPressed ? 0 : 5)
            )
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .opacity(isEnabled ? 1.0 : 0.6)
        }
        .disabled(!isEnabled)
    }
}

// MARK: - Completion View
struct CompletionView: View {
    let animal: AnimalDrawing
    let onNewDrawing: () -> Void
    let onRedraw: () -> Void
    
    @State private var celebrationScale: CGFloat = 0.1
    @State private var starsVisible = false
    @State private var buttonsVisible = false
    
    var body: some View {
        VStack(spacing: 30) {
            // Celebration animation
            ZStack {
                // Stars background
                ForEach(0..<8, id: \.self) { i in
                    Image(systemName: "star.fill")
                        .font(.system(size: 30))
                        .foregroundColor(.yellow)
                        .opacity(starsVisible ? 0.8 : 0)
                        .scaleEffect(starsVisible ? 1.0 : 0.1)
                        .offset(
                            x: cos(CGFloat(i) * .pi / 4) * 100,
                            y: sin(CGFloat(i) * .pi / 4) * 100
                        )
                        .animation(
                            .spring().delay(Double(i) * 0.1),
                            value: starsVisible
                        )
                }
                
                // Trophy
                Image(systemName: "trophy.fill")
                    .font(.system(size: 120))
                    .foregroundColor(.yellow)
                    .scaleEffect(celebrationScale)
                    .rotation3DEffect(
                        .degrees(celebrationScale * 360),
                        axis: (x: 0, y: 1, z: 0)
                    )
            }
            .frame(height: 200)
            .onAppear {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) {
                    celebrationScale = 1.0
                    starsVisible = true
                }
                
                withAnimation(.easeOut.delay(0.8)) {
                    buttonsVisible = true
                }
            }
            
            VStack(spacing: 16) {
                Text("Amazing!")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.purple, .blue],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                
                Text("You drew a wonderful \(animal.name)!")
                    .font(.system(size: 24, weight: .medium, design: .rounded))
                    .multilineTextAlignment(.center)
            }
            
            // Completed drawing
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
                    .shadow(radius: 10)
                
                PixelCanvas(
                    shapes: animal.steps.flatMap { $0.shapes },
                    animalName: animal.name
                )
            }
            .frame(width: 250, height: 250)
            
            // Action buttons
            if buttonsVisible {
                VStack(spacing: 16) {
                    Button(action: onNewDrawing) {
                        HStack {
                            Image(systemName: "paintbrush.fill")
                                .font(.title2)
                            Text("Draw Another")
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 40)
                        .padding(.vertical, 18)
                        .background(
                            RoundedRectangle(cornerRadius: 25)
                                .fill(LinearGradient(
                                    colors: [.green, .blue],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ))
                        )
                        .shadow(radius: 5)
                    }
                    
                    Button(action: onRedraw) {
                        Text("Draw \(animal.name) again")
                            .font(.system(size: 18, weight: .medium, design: .rounded))
                            .foregroundColor(.gray)
                    }
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            
            Spacer()
        }
        .padding()
    }
}

// MARK: - Enhanced Pixel Canvas with Colors
struct PixelCanvas: View {
    let shapes: [PixelShape]
    let animalName: String
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        GeometryReader { _ in
            Canvas { context, size in
                let scale = min(size.width, size.height) / 50
                
                // Always use white/light background like paper for drawing
                context.fill(
                    Path(CGRect(origin: .zero, size: size)),
                    with: .color(Color.white)
                )
                
                // Draw all shapes
                for index in 0..<shapes.count {
                    let shape = shapes[index]
                    var path = Path()
                    
                    // Determine color and style based on shape context
                    let (drawingColor, shouldFill, strokeWidth) = getStyleForShape(shape, at: index, allShapes: shapes)
                    
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
                    
                    // Draw based on determined style
                    if shouldFill {
                        context.fill(path, with: .color(drawingColor))
                        // Add stroke for better visibility on overlapping shapes
                        if strokeWidth > 0 {
                            context.stroke(path, with: .color(drawingColor.opacity(0.8)), lineWidth: strokeWidth * scale)
                        }
                    } else {
                        context.stroke(path, with: .color(drawingColor), lineWidth: max(2, strokeWidth * scale))
                    }
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // Enhanced styling system for better visibility - consistent colors for both modes
    private func getStyleForShape(_ shape: PixelShape, at index: Int, allShapes: [PixelShape]) -> (color: Color, shouldFill: Bool, strokeWidth: CGFloat) {
        // Use consistent colors regardless of color scheme - like drawing on paper
        
        // Special cases for specific animals
        switch animalName {
        case "fox":
            return getFoxColors(shape, at: index)
        case "duck":
            return getDuckColors(shape, at: index)
        case "whale":
            return getWhaleColors(shape, at: index)
        case "panda":
            return getPandaColors(shape, at: index)
        case "penguin":
            return getPenguinColors(shape, at: index)
        case "cow":
            return getCowColors(shape, at: index)
        case "sheep":
            return getSheepColors(shape, at: index)
        default:
            break
        }
        
        // Analyze shape characteristics
        switch shape {
        case let .circle(center, radius):
            // Check if this is a pupil (small circle at same position as a previously drawn larger circle)
            let isPupil = radius <= 1.5 && center.y >= 15 && center.y <= 25 && allShapes.prefix(index).contains { otherShape in
                if case let .circle(otherCenter, otherRadius) = otherShape,
                   abs(otherCenter.x - center.x) < 1 && abs(otherCenter.y - center.y) < 1 && otherRadius > radius + 0.5 {
                    return true
                }
                return false
            }
            
            if isPupil {
                // White pupils for contrast against black eyes
                return (Color.white, true, 0)
            }
            // Eyes (small circles, typically positioned symmetrically around the center)
            else if radius > 0.5 && radius <= 3 && center.y >= 15 && center.y <= 25 &&
                    center.x >= 15 && center.x <= 35 {
                // Black eyes
                return (Color.black, true, 0)
            }
            // Nose (small circle in center)
            else if radius <= 2 && abs(center.x - 25) < 5 && center.y >= 26 && center.y <= 35 {
                return (Color(red: 1.0, green: 0.4, blue: 0.5), true, 0)
            }
            // Ears (larger circles, positioned on sides)
            else if radius >= 4 && center.y < 20 {
                // Check if it's an inner ear
                if index > 2 && radius <= 2 {
                    return (Color(red: 1.0, green: 0.6, blue: 0.7), true, 0)
                }
                return (Color(red: 0.6, green: 0.4, blue: 0.2), true, 0.5)
            }
            // Head (largest circle, usually first)
            else if index == 0 && radius > 10 {
                return (Color.black, false, 0.8)
            }
            // Whisker spots or tiny decorative dots (very small, often on the sides)
            else if radius <= 0.5 {
                return (Color.black.opacity(0.5), true, 0)
            }
            // Other features (spots, cheeks, etc.)
            else if radius < 1.5 {
                // Small dots/spots
                return (Color.gray.opacity(0.7), true, 0)
            }
            else {
                return (Color.gray.opacity(0.5), true, 0.3)
            }
            
        case let .ellipse(center, radiusX, radiusY):
            // Body parts (large ellipses)
            if radiusX > 8 || radiusY > 8 {
                return (Color.black, false, 0.8)
            }
            // Eye patches (for pandas) - always black
            else if center.y < 25 && radiusX > 3 {
                return (Color.black, true, 0)
            }
            // Snouts/muzzles
            else if center.y > 25 && center.y < 35 {
                return (Color(red: 0.8, green: 0.6, blue: 0.4), true, 0.3)
            }
            // Other features
            else {
                return (Color.gray.opacity(0.4), true, 0.3)
            }
            
        case .triangle(let p1, let p2, let p3):
            // Calculate triangle center
            let centerY = (p1.y + p2.y + p3.y) / 3
            let centerX = (p1.x + p2.x + p3.x) / 3
            
            // Ears (triangles on top)
            if centerY < 20 {
                // Inner ears (smaller triangles)
                if index > 2 && index < 6 {
                    return (Color(red: 1.0, green: 0.6, blue: 0.7), true, 0)
                }
                // Outer ears
                return (Color(red: 0.6, green: 0.4, blue: 0.2), true, 0.3)
            }
            // Noses (triangles in center)
            else if abs(centerX - 25) < 3 && centerY > 25 && centerY < 32 {
                return (Color(red: 1.0, green: 0.4, blue: 0.5), true, 0)
            }
            // Beaks or other features
            else {
                return (Color.orange, true, 0.3)
            }
            
        case .line, .polyline:
            // Whiskers (lines extending from face)
            if case let .line(from, to) = shape,
               (from.x < 20 || from.x > 30) && abs(from.y - to.y) < 5 {
                return (Color.black.opacity(0.6), false, 0.5)
            }
            // Mouths and smiles
            else {
                return (Color.black.opacity(0.8), false, 0.6)
            }
            
        case .rectangle, .square:
            // Snouts (rectangles in lower face area)
            if case let .rectangle(origin, _) = shape,
               origin.y > 25 && origin.y < 40 {
                return (Color(red: 0.8, green: 0.6, blue: 0.4), true, 0.3)
            }
            // Other features
            else {
                return (Color.gray.opacity(0.4), true, 0.3)
            }
        }
    }
    
    // Special color functions for specific animals
    private func getFoxColors(_ shape: PixelShape, at index: Int) -> (color: Color, shouldFill: Bool, strokeWidth: CGFloat) {
        switch shape {
        case .circle:
            // Head is the first circle
            if index == 0 {
                return (Color.orange, false, 0.8)
            }
            // Nose
            return (Color.black, true, 0)
            
        case .triangle:
            // Ears (first two triangles)
            if index < 2 {
                return (Color.orange, true, 0.5)
            }
            // Inner ears (black)
            else if index < 4 {
                return (Color.black, true, 0)
            }
            // Snout
            else {
                return (Color(red: 1.0, green: 0.8, blue: 0.6), true, 0.3)
            }
            
        case .ellipse:
            // Eyes - with pupils being smaller ellipses
            if index == 4 || index == 5 {
                return (Color.black, true, 0)
            }
            else {
                return (Color.black, true, 0)
            }
            
        case .polyline:
            // Cheek fluff
            if index > 7 {
                return (Color.orange.opacity(0.6), false, 0.8)
            }
            // Smile
            return (Color.black.opacity(0.8), false, 0.6)
            
        case .line:
            // Whiskers
            return (Color.black.opacity(0.6), false, 0.5)
            
        default:
            return (Color.black.opacity(0.8), false, 0.6)
        }
    }
    
    private func getDuckColors(_ shape: PixelShape, at index: Int) -> (color: Color, shouldFill: Bool, strokeWidth: CGFloat) {
        switch shape {
        case .circle:
            // Head
            if index == 0 {
                return (Color.yellow, false, 0.8)
            }
            // Eyes
            return (Color.black, true, 0)
            
        case .ellipse:
            // Body
            if index == 1 {
                return (Color.yellow, false, 0.8)
            }
            // Bill
            else if index == 2 {
                return (Color.orange, true, 0.3)
            }
            // Wing
            else {
                return (Color.yellow.opacity(0.7), true, 0.3)
            }
            
        case .polyline:
            // Webbed feet
            return (Color.orange, true, 0)
            
        case .triangle:
            // Tail feathers
            return (Color.yellow.opacity(0.8), true, 0.3)
            
        default:
            return (Color.black.opacity(0.8), false, 0.6)
        }
    }
    
    private func getWhaleColors(_ shape: PixelShape, at index: Int) -> (color: Color, shouldFill: Bool, strokeWidth: CGFloat) {
        switch shape {
        case .ellipse:
            // Body (first ellipse) or fins
            if index == 0 {
                return (Color.blue.opacity(0.7), false, 0.8)
            }
            // Blowhole
            else if index == 4 {
                return (Color.blue.opacity(0.5), true, 0.3)
            }
            // Fins
            else {
                return (Color.blue.opacity(0.6), true, 0.3)
            }
            
        case .triangle:
            // Tail flukes
            return (Color.blue.opacity(0.7), true, 0.3)
            
        case .circle:
            // Eye
            return (Color.black, true, 0)
            
        case .polyline:
            // Water spout or smile
            if index == 5 {
                return (Color.blue.opacity(0.3), false, 0.8)
            }
            return (Color.black.opacity(0.6), false, 0.5)
            
        default:
            return (Color.black.opacity(0.8), false, 0.6)
        }
    }
    
    private func getPandaColors(_ shape: PixelShape, at index: Int) -> (color: Color, shouldFill: Bool, strokeWidth: CGFloat) {
        switch shape {
        case let .circle(_, radius):
            // Head (first shape, index 0)
            if index == 0 {
                return (Color.black, false, 0.8)
            }
            // Ears (index 1-2, radius 5)
            else if index == 1 || index == 2 {
                return (Color.black, true, 0)
            }
            // Eyes (index 5-6, radius 2)
            else if index == 5 || index == 6 {
                return (Color.black, true, 0)
            }
            // Eye sparkles (index 7-8, radius ~0.6)
            else if index == 7 || index == 8 {
                return (Color.white, true, 0)
            }
            // Default for any other circles
            else {
                return (Color.black, true, 0)
            }
            
        case .ellipse:
            // Eye patches (index 3-4)
            if index == 3 || index == 4 {
                return (Color.black, true, 0)
            }
            // Muzzle area (index 10)
            else {
                return (Color.white, true, 0.3)
            }
            
        case .triangle:
            // Nose (index 9)
            return (Color.black, true, 0)
            
        default:
            // Smile (polyline)
            return (Color.black.opacity(0.8), false, 0.6)
        }
    }
    
    private func getPenguinColors(_ shape: PixelShape, at index: Int) -> (color: Color, shouldFill: Bool, strokeWidth: CGFloat) {
        switch shape {
        case .circle:
            // Head or eyes
            if index == 0 {
                return (Color.black, false, 0.8)
            }
            return (Color.black, true, 0)
            
        case .ellipse:
            // Body
            if index == 1 {
                return (Color.black, false, 0.8)
            }
            // White belly
            else if index == 4 {
                return (Color.white, true, 0.5)
            }
            // Flippers
            else {
                return (Color.black, true, 0.3)
            }
            
        case .triangle:
            // Beak
            return (Color.orange, true, 0)
            
        case .polyline:
            // Feet
            return (Color.orange, true, 0)
            
        default:
            return (Color.black.opacity(0.8), false, 0.6)
        }
    }
    
    private func getCowColors(_ shape: PixelShape, at index: Int) -> (color: Color, shouldFill: Bool, strokeWidth: CGFloat) {
        switch shape {
        case let .circle(_, radius):
            // Head (first shape)
            if index == 0 {
                return (Color(red: 0.9, green: 0.8, blue: 0.7), false, 0.8)
            }
            // Eyes
            else if radius >= 2 && radius <= 2.5 {
                return (Color.black, true, 0)
            }
            // Small pupils or bell
            else if radius <= 1 || index > 20 {
                if index > 20 {
                    return (Color.yellow, true, 0.5)
                }
                return (Color.black, true, 0)
            }
            // Spots
            else {
                return (Color.black, true, 0)
            }
            
        case .ellipse:
            // Ears
            if index < 3 {
                return (Color(red: 0.8, green: 0.6, blue: 0.5), true, 0.3)
            }
            // Snout (pink)
            else if index == 4 {
                return (Color(red: 1.0, green: 0.7, blue: 0.7), true, 0.3)
            }
            // Nostrils or spots
            else {
                return (Color.black, true, 0)
            }
            
        case .line:
            // Eyelashes
            return (Color.black, false, 0.4)
            
        case .polyline:
            // Horns or smile
            if index < 20 {
                return (Color(red: 0.6, green: 0.5, blue: 0.4), false, 0.8)
            }
            return (Color.black.opacity(0.8), false, 0.6)
            
        case .rectangle:
            // Bell strap
            return (Color(red: 0.6, green: 0.4, blue: 0.2), true, 0)
            
        default:
            return (Color.black.opacity(0.8), false, 0.6)
        }
    }
    
    private func getSheepColors(_ shape: PixelShape, at index: Int) -> (color: Color, shouldFill: Bool, strokeWidth: CGFloat) {
        switch shape {
        case let .circle(_, radius):
            // Head (first shape)
            if index == 0 {
                return (Color.white, false, 0.8)
            }
            // Wool bumps
            else if radius >= 2.5 {
                return (Color.white, true, 0.5)
            }
            // Eyes or other small features
            else {
                return (Color.black, true, 0)
            }
            
        case .ellipse:
            // Face (dark)
            if index == 11 {
                return (Color(red: 0.3, green: 0.3, blue: 0.3), true, 0)
            }
            // Ears (pink)
            else if index < 14 {
                return (Color(red: 1.0, green: 0.7, blue: 0.7), true, 0.3)
            }
            // Sleepy eyes
            else {
                return (Color.white, true, 0)
            }
            
        case .triangle:
            // Nose (pink)
            return (Color(red: 1.0, green: 0.6, blue: 0.7), true, 0)
            
        case .polyline:
            // Smile
            return (Color.white, false, 0.5)
            
        case .rectangle:
            // Hooves
            return (Color.black, true, 0)
            
        default:
            return (Color.black.opacity(0.8), false, 0.6)
        }
    }
}

// MARK: - Preview
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
