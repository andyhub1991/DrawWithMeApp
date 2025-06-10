import SwiftUI
import CoreGraphics

// MARK: — JSON-Compatible Point and Size Structs

struct Point: Codable {
    let x: CGFloat
    let y: CGFloat
    
    var cgPoint: CGPoint {
        return CGPoint(x: x, y: y)
    }
}

struct Size: Codable {
    let width: CGFloat
    let height: CGFloat
    
    var cgSize: CGSize {
        return CGSize(width: width, height: height)
    }
}

// MARK: — Pixel Primitives

enum PixelShape: Codable {
    case circle(center: Point, radius: CGFloat)
    case ellipse(center: Point, radiusX: CGFloat, radiusY: CGFloat)
    case square(origin: Point, side: CGFloat)
    case rectangle(origin: Point, size: Size)
    case triangle(p1: Point, p2: Point, p3: Point)
    case line(from: Point, to: Point)
    case polyline(points: [Point])
    
    enum CodingKeys: String, CodingKey {
        case type, center, radius, radiusX, radiusY, origin, side, size, p1, p2, p3, from, to, points
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        
        switch type {
        case "circle":
            let center = try container.decode(Point.self, forKey: .center)
            let radius = try container.decode(CGFloat.self, forKey: .radius)
            self = .circle(center: center, radius: radius)
            
        case "ellipse":
            let center = try container.decode(Point.self, forKey: .center)
            let radiusX = try container.decode(CGFloat.self, forKey: .radiusX)
            let radiusY = try container.decode(CGFloat.self, forKey: .radiusY)
            self = .ellipse(center: center, radiusX: radiusX, radiusY: radiusY)
            
        case "square":
            let origin = try container.decode(Point.self, forKey: .origin)
            let side = try container.decode(CGFloat.self, forKey: .side)
            self = .square(origin: origin, side: side)
            
        case "rectangle":
            let origin = try container.decode(Point.self, forKey: .origin)
            let size = try container.decode(Size.self, forKey: .size)
            self = .rectangle(origin: origin, size: size)
            
        case "triangle":
            let p1 = try container.decode(Point.self, forKey: .p1)
            let p2 = try container.decode(Point.self, forKey: .p2)
            let p3 = try container.decode(Point.self, forKey: .p3)
            self = .triangle(p1: p1, p2: p2, p3: p3)
            
        case "line":
            let from = try container.decode(Point.self, forKey: .from)
            let to = try container.decode(Point.self, forKey: .to)
            self = .line(from: from, to: to)
            
        case "polyline":
            let points = try container.decode([Point].self, forKey: .points)
            self = .polyline(points: points)
            
        default:
            throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Unknown shape type")
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .circle(let center, let radius):
            try container.encode("circle", forKey: .type)
            try container.encode(center, forKey: .center)
            try container.encode(radius, forKey: .radius)
            
        case .ellipse(let center, let radiusX, let radiusY):
            try container.encode("ellipse", forKey: .type)
            try container.encode(center, forKey: .center)
            try container.encode(radiusX, forKey: .radiusX)
            try container.encode(radiusY, forKey: .radiusY)
            
        case .square(let origin, let side):
            try container.encode("square", forKey: .type)
            try container.encode(origin, forKey: .origin)
            try container.encode(side, forKey: .side)
            
        case .rectangle(let origin, let size):
            try container.encode("rectangle", forKey: .type)
            try container.encode(origin, forKey: .origin)
            try container.encode(size, forKey: .size)
            
        case .triangle(let p1, let p2, let p3):
            try container.encode("triangle", forKey: .type)
            try container.encode(p1, forKey: .p1)
            try container.encode(p2, forKey: .p2)
            try container.encode(p3, forKey: .p3)
            
        case .line(let from, let to):
            try container.encode("line", forKey: .type)
            try container.encode(from, forKey: .from)
            try container.encode(to, forKey: .to)
            
        case .polyline(let points):
            try container.encode("polyline", forKey: .type)
            try container.encode(points, forKey: .points)
        }
    }
}

// MARK: — Step & Drawing Models

struct Step: Identifiable, Codable {
    let id = UUID()
    let instruction: String
    let shapes: [PixelShape]
    
    // Custom coding keys to exclude auto-generated id
    enum CodingKeys: String, CodingKey {
        case instruction, shapes
    }
}

struct AnimalDrawing: Codable {
    let name: String
    let tier: Int?
    let difficulty: String?
    let steps: [Step]
}

// MARK: — Main View

struct ContentView: View {
    @State private var animalInput = ""
    @State private var drawing: AnimalDrawing?
    @State private var stepIndex = 0

    var body: some View {
        NavigationView {
            if let drawing = drawing {
                VStack(spacing: 16) {
                    Text("Drawing: \(drawing.name.capitalized)")
                        .font(.title2).bold()

                    PixelCanvas(
                        shapes: drawing.steps
                            .prefix(stepIndex + 1)
                            .flatMap { $0.shapes }
                    )
                    .frame(width: 300, height: 300)
                    .border(Color.gray)

                    Text(drawing.steps[stepIndex].instruction)
                        .font(.headline)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    HStack {
                        Button("Prev") {
                            stepIndex = max(stepIndex - 1, 0)
                        }
                        .disabled(stepIndex == 0)

                        Spacer()

                        Button(stepIndex < drawing.steps.count - 1 ? "Next" : "Done") {
                            if stepIndex < drawing.steps.count - 1 {
                                stepIndex += 1
                            } else {
                                reset()
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding()
                .navigationBarHidden(true)

            } else {
                VStack(spacing: 16) {
                    Text("What animal do you want to draw?")
                        .font(.title2)

                    TextField("bear, pig, frog, owl, rabbit, mouse, elephant, lion...", text: $animalInput)
                        .textFieldStyle(.roundedBorder)
                        .padding(.horizontal)

                    Button("Start") {
                        loadDrawing(for: animalInput.lowercased())
                    }
                    .disabled(animalInput.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding()
                .navigationTitle("PixelArt MVP")
            }
        }
    }

    private func loadDrawing(for animal: String) {
        drawing = AnimalDatabase.shared.getAnimal(named: animal)
        stepIndex = 0
    }

    private func reset() {
        drawing = nil
        animalInput = ""
        stepIndex = 0
    }
}

// MARK: — Canvas Renderer

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

// MARK: — Preview

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .preferredColorScheme(.light)
        ContentView()
            .preferredColorScheme(.dark)
    }
}
