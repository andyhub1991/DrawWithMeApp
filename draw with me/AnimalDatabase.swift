
// MARK: - 2. CREATE NEW FILE: AnimalDatabase.swift

import Foundation

struct AnimalData: Codable {
    let animals: [AnimalDrawing]
}

class AnimalDatabase {
    static let shared = AnimalDatabase()
    private var loadedAnimals: [String: AnimalDrawing] = [:]
    
    private init() {
        loadAnimalsFromJSON()
    }
    
    private func loadAnimalsFromJSON() {
        guard let path = Bundle.main.path(forResource: "animals", ofType: "json"),
              let data = NSData(contentsOfFile: path) else {
            print("Could not find animals.json file")
            return
        }
        
        do {
            let animalData = try JSONDecoder().decode(AnimalData.self, from: data as Data)
            for animal in animalData.animals {
                loadedAnimals[animal.name.lowercased()] = animal
            }
            print("Loaded \(loadedAnimals.count) animals from JSON")
        } catch {
            print("Error loading animals: \(error)")
        }
    }
    
    func getAnimal(named name: String) -> AnimalDrawing? {
        return loadedAnimals[name.lowercased()]
    }
    
    func getAllAnimalNames() -> [String] {
        return Array(loadedAnimals.keys).sorted()
    }
    
    func getAnimalsByTier(_ tier: Int) -> [AnimalDrawing] {
        return loadedAnimals.values.filter { $0.tier == tier }
    }
}
