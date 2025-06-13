import Foundation

// MARK: - Animal Suggestion Types
enum AnimalSuggestion {
    case exact(AnimalDrawing)
    case suggestion(String)
    case random([AnimalDrawing])
}

struct AnimalData: Codable {
    let animals: [AnimalDrawing]
}

class AnimalDatabase {
    static let shared = AnimalDatabase()
    private var loadedAnimals: [String: AnimalDrawing] = [:]
    
    // Animal categories for smart suggestions
    private let animalCategories: [String: [String]] = [
        "pets": ["cat", "dog", "rabbit", "mouse"],
        "farm": ["cow", "pig", "sheep", "chicken", "horse", "duck"],
        "wild": ["lion", "tiger", "elephant", "monkey", "bear", "fox"],
        "water": ["fish", "duck", "seal", "whale", "penguin", "frog", "turtle"],
        "birds": ["owl", "chicken", "duck", "penguin"],
        "cute": ["panda", "rabbit", "cat", "dog", "mouse", "sheep"]
    ]
    
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
    
    // MARK: - Smart Matching
    func findBestMatch(for input: String) -> AnimalSuggestion {
        let normalized = input.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 1. Exact match
        if let exact = getAnimal(named: normalized) {
            return .exact(exact)
        }
        
        // 2. Check if input contains an animal name
        let allAnimals = getAllAnimalNames()
        for animal in allAnimals {
            if normalized.contains(animal) || animal.contains(normalized) {
                if let found = getAnimal(named: animal) {
                    return .exact(found)
                }
            }
        }
        
        // 3. Fuzzy matching using Levenshtein distance
        let closeMatches = findCloseMatches(for: normalized, in: allAnimals)
        if let closest = closeMatches.first {
            return .suggestion(closest)
        }
        
        // 4. No match - suggest random from appropriate tier
        let suggestions = getSuggestionsForUser(basedOn: normalized)
        return .random(suggestions)
    }
    
    // Simple Levenshtein distance for fuzzy matching
    private func findCloseMatches(for input: String, in animals: [String], threshold: Int = 2) -> [String] {
        return animals.filter { animal in
            levenshteinDistance(input, animal) <= threshold
        }.sorted { animal1, animal2 in
            levenshteinDistance(input, animal1) < levenshteinDistance(input, animal2)
        }
    }
    
    private func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
        let m = s1.count
        let n = s2.count
        
        if m == 0 { return n }
        if n == 0 { return m }
        
        var matrix = Array(repeating: Array(repeating: 0, count: n + 1), count: m + 1)
        
        for i in 0...m {
            matrix[i][0] = i
        }
        
        for j in 0...n {
            matrix[0][j] = j
        }
        
        let s1Array = Array(s1)
        let s2Array = Array(s2)
        
        for i in 1...m {
            for j in 1...n {
                let cost = s1Array[i-1] == s2Array[j-1] ? 0 : 1
                matrix[i][j] = min(
                    matrix[i-1][j] + 1,      // deletion
                    matrix[i][j-1] + 1,      // insertion
                    matrix[i-1][j-1] + cost  // substitution
                )
            }
        }
        
        return matrix[m][n]
    }
    
    // MARK: - Smart Suggestions
    func getSuggestionsForUser(basedOn input: String? = nil) -> [AnimalDrawing] {
        // Start with tier 1 (easiest) animals
        var suggestions = getAnimalsByTier(1).shuffled()
        
        // If we have context from failed input, try to be smart
        if let input = input {
            // Check if input matches any category keywords
            for (category, animals) in animalCategories {
                if input.contains(category) {
                    let categoryAnimals = animals.compactMap { getAnimal(named: $0) }
                    if !categoryAnimals.isEmpty {
                        suggestions = categoryAnimals.shuffled()
                        break
                    }
                }
            }
        }
        
        // Return top 3 suggestions
        return Array(suggestions.prefix(3))
    }
    
    func getRelatedAnimals(to animalName: String) -> [String] {
        // Find which categories this animal belongs to
        var relatedAnimals: Set<String> = []
        
        for (_, animals) in animalCategories {
            if animals.contains(animalName) {
                // Add all animals from this category except the current one
                for animal in animals where animal != animalName {
                    relatedAnimals.insert(animal)
                }
            }
        }
        
        // If we don't have enough related animals, add some from the same tier
        if let currentAnimal = getAnimal(named: animalName) {
            let sameTierAnimals = getAnimalsByTier(currentAnimal.tier ?? 1)
                .map { $0.name }
                .filter { $0 != animalName }
            
            for animal in sameTierAnimals {
                relatedAnimals.insert(animal)
                if relatedAnimals.count >= 5 { break }
            }
        }
        
        return Array(relatedAnimals).shuffled().prefix(3).map { $0 }
    }
    
    // MARK: - Progress Tracking (for future enhancement)
    func getRecommendedNextAnimal(afterCompleting animalName: String) -> [String] {
        // Get animals the user hasn't drawn yet (would need to track this)
        // For now, just return related animals
        return getRelatedAnimals(to: animalName)
    }
}
