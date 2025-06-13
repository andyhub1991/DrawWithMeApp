import SwiftUI
import CoreGraphics

// MARK: - JSON-Compatible Point and Size Structs

struct Point: Codable, Equatable {
    let x: CGFloat
    let y: CGFloat
    
    var cgPoint: CGPoint {
        return CGPoint(x: x, y: y)
    }
}

struct Size: Codable, Equatable {
    let width: CGFloat
    let height: CGFloat
    
    var cgSize: CGSize {
        return CGSize(width: width, height: height)
    }
}

// MARK: - Pixel Primitives

enum PixelShape: Codable, Equatable {
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

// MARK: - Step & Drawing Models

struct Step: Identifiable, Codable, Equatable {
    let id = UUID()
    let instruction: String
    let shapes: [PixelShape]
    
    // Custom coding keys to exclude auto-generated id
    enum CodingKeys: String, CodingKey {
        case instruction, shapes
    }
    
    static func == (lhs: Step, rhs: Step) -> Bool {
        return lhs.instruction == rhs.instruction && lhs.shapes == rhs.shapes
    }
}

struct AnimalDrawing: Codable, Equatable {
    let name: String
    let tier: Int?
    let difficulty: String?
    let steps: [Step]
    
    static func == (lhs: AnimalDrawing, rhs: AnimalDrawing) -> Bool {
        return lhs.name == rhs.name
    }
}
