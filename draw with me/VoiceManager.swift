import SwiftUI
import Speech
import AVFoundation

// MARK: - Simple Voice Manager
class VoiceManager: NSObject, ObservableObject {
    @Published var isListening = false
    @Published var recognizedText = ""
    @Published var currentCommand: Command?
    @Published var wakeWordDetected = false
    
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    // Simple command types
    enum Command: Equatable {
        case drawAnimal(String)
        case next
        case back
        case done
    }
    
    override init() {
        super.init()
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        requestPermissions()
    }
    
    deinit {
        stopListening()
    }
    
    // MARK: - Permissions
    private func requestPermissions() {
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                switch status {
                case .authorized:
                    print("Speech recognition authorized")
                case .denied, .restricted, .notDetermined:
                    print("Speech recognition not available")
                @unknown default:
                    break
                }
            }
        }
        
        AVAudioApplication.requestRecordPermission { granted in
            print("Microphone permission: \(granted)")
        }
    }
    
    // MARK: - Push to Talk
    func startListening() {
        guard !isListening else { return }
        
        // Check permissions first
        guard speechRecognizer != nil else {
            print("Speech recognizer not available")
            return
        }
        
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            guard status == .authorized else {
                print("Speech recognition not authorized")
                return
            }
            
            DispatchQueue.main.async {
                do {
                    try self?.startRecognition()
                    self?.isListening = true
                } catch {
                    print("Failed to start recognition: \(error)")
                }
            }
        }
    }
    
    func stopListening() {
        // Remove the tap before stopping
        audioEngine.inputNode.removeTap(onBus: 0)
        
        audioEngine.stop()
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        
        isListening = false
        recognitionTask = nil
        recognitionRequest = nil
        
        // Reset audio session
        try? AVAudioSession.sharedInstance().setActive(false)
    }
    
    private func startRecognition() throws {
        // Cancel any ongoing task
        recognitionTask?.cancel()
        recognitionTask = nil
        
        // Configure audio session
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        
        let inputNode = audioEngine.inputNode
        
        // Remove any existing tap
        inputNode.removeTap(onBus: 0)
        
        guard let recognitionRequest = recognitionRequest else { return }
        
        recognitionRequest.shouldReportPartialResults = true
        
        // Start recognition
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }
            
            if let result = result {
                let text = result.bestTranscription.formattedString
                DispatchQueue.main.async {
                    self.recognizedText = text
                    self.processCommand(text)
                }
            }
            
            if error != nil || result?.isFinal == true {
                self.stopListening()
            }
        }
        
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)
        }
        
        audioEngine.prepare()
        try audioEngine.start()
    }
    
    // MARK: - Wake Word Detection
    func startWakeWordDetection() {
        // Simplified: just use push-to-talk for now
        // In production, you'd use a dedicated wake word engine
        print("Wake word detection would start here")
    }
    
    // MARK: - Command Processing
    private func processCommand(_ text: String) {
        let lowercased = text.lowercased()
        print("Processing command: \(lowercased)")
        
        // Check for wake words first
        if lowercased.contains("hey draw") || lowercased.contains("let's draw") {
            wakeWordDetected = true
            return
        }
        
        // Simple command matching
        if lowercased.contains("next") || lowercased.contains("continue") {
            currentCommand = .next
            print("Command recognized: next")
        } else if lowercased.contains("back") || lowercased.contains("previous") || lowercased.contains("go back") {
            currentCommand = .back
            print("Command recognized: back")
        } else if lowercased.contains("done") || lowercased.contains("finish") || lowercased.contains("stop") {
            currentCommand = .done
            print("Command recognized: done")
        } else {
            // Check for draw commands - be more flexible
            let drawKeywords = ["draw", "make", "create", "show", "let's do", "want"]
            let containsDrawKeyword = drawKeywords.contains { lowercased.contains($0) }
            
            if containsDrawKeyword || true { // Always check for animals even without keyword
                // Extract animal name
                let animals = ["cat", "dog", "horse", "panda", "bear", "pig", "frog", "owl", "monkey", "sheep", "rabbit", "mouse", "elephant", "lion", "tiger", "fox", "cow", "duck", "chicken", "fish", "turtle", "penguin", "seal", "whale"]
                
                for animal in animals {
                    if lowercased.contains(animal) {
                        currentCommand = .drawAnimal(animal)
                        print("Command recognized: draw \(animal)")
                        break
                    }
                }
            }
        }
    }
}

// MARK: - Audio Feedback
class AudioFeedback: ObservableObject {
    private let synthesizer = AVSpeechSynthesizer()
    
    func speak(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = 0.45 // Slower for kids
        utterance.pitchMultiplier = 1.1 // Slightly higher pitch
        utterance.volume = 0.9
        
        // Use a fun voice if available
        if let voice = AVSpeechSynthesisVoice(language: "en-US") {
            utterance.voice = voice
        }
        
        synthesizer.speak(utterance)
    }
    
    func announceStep(_ instruction: String) {
        speak(instruction)
    }
    
    func confirmCommand(_ animal: String) {
        speak("Great! Let's draw a \(animal)!")
    }
}
