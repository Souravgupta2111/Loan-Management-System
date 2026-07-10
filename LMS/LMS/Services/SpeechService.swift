import Foundation
import Combine
import Speech
import AVFoundation

@MainActor
final class SpeechService: ObservableObject {
    
    @Published var isListening = false
    @Published var transcribedText = ""
    @Published var isSpeaking = false
    @Published var speechError: String?
    
    private var speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-IN"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    private let synthesizer = AVSpeechSynthesizer()
    private var speechDelegate: SpeechSynthesizerDelegate?
    
    init() {
        speechDelegate = SpeechSynthesizerDelegate { [weak self] in
            Task { @MainActor in
                self?.isSpeaking = false
            }
        }
        synthesizer.delegate = speechDelegate
    }
    
    
    func requestSpeechPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }
    
    func requestMicrophonePermission() async -> Bool {
        await AVAudioApplication.requestRecordPermission()
    }
    
    
    func startListening() {
        if audioEngine.isRunning {
            stopListening()
            return
        }
        
        Task {
            let speechGranted = await requestSpeechPermission()
            let micGranted = await requestMicrophonePermission()
            
            guard speechGranted, micGranted else {
                speechError = "Permissions denied. Please enable in Settings."
                return
            }
            
            do {
                try await Task.detached(priority: .userInitiated) {
                    try self.startAudioSession()
                }.value
                try startRecognition()
                isListening = true
                speechError = nil
                print("🎙️ Started recording successfully")
            } catch {
                print("❌ Voice input error: \(error.localizedDescription)")
                speechError = "Could not start voice input: \(error.localizedDescription)"
                isListening = false
            }
        }
    }
    
    func stopListening() {
        guard isListening else { return } // Prevent infinite recursive stopping loop
        isListening = false
        
        if audioEngine.isRunning {
            audioEngine.inputNode.removeTap(onBus: 0)
            audioEngine.stop()
        }
        
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        
        recognitionTask = nil
        recognitionRequest = nil
        

    }
    
    private func isBenignRecognitionError(_ error: NSError) -> Bool {
        if error.domain == "kAFAssistantErrorDomain" {
            return [203, 216, 1101, 1110, 0].contains(error.code)
        }
        if error.domain == NSURLErrorDomain && error.code == NSURLErrorCancelled {
            return true
        }
        return false
    }

    nonisolated private func startAudioSession() throws {
        let audioSession = AVAudioSession.sharedInstance()

        try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
    }
    
    private func startRecognition() throws {
        recognitionTask?.cancel()
        self.recognitionTask = nil
        
        self.speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-IN"))

        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            throw NSError(domain: "SpeechService", code: 2, userInfo: [NSLocalizedDescriptionKey: "Speech recognizer is not available right now. Check your network connection."])
        }

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()

        guard let request = recognitionRequest else {
            throw NSError(domain: "SpeechService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to create recognition request"])
        }

        request.shouldReportPartialResults = true

        request.requiresOnDeviceRecognition = false

        recognitionTask = speechRecognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor in
                guard let self = self else { return }
                
                var isFinal = false

                if let result = result {
                    self.transcribedText = result.bestTranscription.formattedString
                    isFinal = result.isFinal
                    print("🗣️ Transcribed so far: \(self.transcribedText)")
                }

                if let error = error {
                    let nsError = error as NSError
                    print("⚠️ Recognition ended: \(nsError.domain) \(nsError.code) — \(error.localizedDescription)")

                    if !self.isBenignRecognitionError(nsError) {
                        #if targetEnvironment(simulator)
                        self.speechError = "Voice input isn't supported in the iOS Simulator. Please test on a real device."
                        #else
                        self.speechError = "Voice input is unavailable right now. Please check your connection and try again."
                        #endif
                    }
                    self.stopListening()
                } else if isFinal {
                    self.stopListening()
                }
            }
        }
        
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        inputNode.removeTap(onBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] (buffer: AVAudioPCMBuffer, when: AVAudioTime) in
            self?.recognitionRequest?.append(buffer)
        }
        
        audioEngine.prepare()
        try audioEngine.start()
    }
    
    
    func speak(_ text: String) {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        
        let cleanText = text
            .replacingOccurrences(of: "**", with: "")
            .replacingOccurrences(of: "*", with: "")
            .replacingOccurrences(of: "#", with: "")
            .replacingOccurrences(of: "`", with: "")
            .replacingOccurrences(of: "₹", with: "rupees ")
        
        let utterance = AVSpeechUtterance(string: cleanText)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-IN")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.95 // Slightly slower for clarity
        utterance.pitchMultiplier = 1.05
        utterance.volume = 1.0
        

        try? AVAudioSession.sharedInstance().setActive(true)
        
        isSpeaking = true
        synthesizer.speak(utterance)
    }
    
    func stopSpeaking() {
        synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
    }
}

private class SpeechSynthesizerDelegate: NSObject, AVSpeechSynthesizerDelegate {
    let onFinish: () -> Void
    
    init(onFinish: @escaping () -> Void) {
        self.onFinish = onFinish
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        onFinish()
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        onFinish()
    }
}
