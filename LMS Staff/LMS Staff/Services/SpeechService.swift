//
//  SpeechService.swift
//  LMS
//
//  Handles voice input (Speech-to-Text) and voice output (Text-to-Speech)
//  using Apple's free, on-device Speech & AVFoundation frameworks.
//

import Foundation
import Combine
import Speech
import AVFoundation

@MainActor
final class SpeechService: ObservableObject {
    
    // MARK: - Published State
    @Published var isListening = false
    @Published var transcribedText = ""
    @Published var isSpeaking = false
    @Published var speechError: String?
    
    // MARK: - Speech-to-Text (Voice Input)
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-IN"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    // MARK: - Text-to-Speech (Voice Output)
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
    
    // MARK: - Permission
    
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
    
    // MARK: - Voice Input (Start Listening)
    
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
                try startAudioSession()
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
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        
        recognitionTask = nil
        recognitionRequest = nil
        isListening = false
        
        // Deactivate audio session so TTS can use it smoothly
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
    
    private func startAudioSession() throws {
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
    }
    
    private func startRecognition() throws {
        recognitionTask?.cancel()
        self.recognitionTask = nil

        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            throw NSError(domain: "SpeechService", code: 2, userInfo: [NSLocalizedDescriptionKey: "Speech recognizer is not available right now. Check your network connection."])
        }

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()

        guard let request = recognitionRequest else {
            throw NSError(domain: "SpeechService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to create recognition request"])
        }

        request.shouldReportPartialResults = true
        
        // Enforce on-device recognition only if supported to avoid simulator crashes, 
        // matching the behavior in the B-easy project.
        if #available(iOS 13, *), speechRecognizer.supportsOnDeviceRecognition {
            // Note: On simulators, this might still be true but fail if models aren't downloaded. 
            // In the B-easy project, this wasn't enforced at all, which is why it worked on simulator.
            // request.requiresOnDeviceRecognition = true 
        }
        
        // 1. MUST create the recognition task BEFORE installing the tap and starting the engine
        recognitionTask = speechRecognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor in
                guard let self = self else { return }
                
                var isFinal = false
                
                if let result = result {
                    self.transcribedText = result.bestTranscription.formattedString
                    isFinal = result.isFinal
                    print("🗣️ Transcribed so far: \(self.transcribedText)")
                }
                
                if error != nil || isFinal {
                    if let error = error { print("❌ Recognition error: \(error.localizedDescription)") }
                    self.stopListening()
                }
            }
        }
        
        // 2. Configure audio engine and tap AFTER task is created
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        // Remove any existing tap just in case
        inputNode.removeTap(onBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] (buffer: AVAudioPCMBuffer, when: AVAudioTime) in
            self?.recognitionRequest?.append(buffer)
        }
        
        // 3. Start engine
        audioEngine.prepare()
        try audioEngine.start()
    }
    
    // MARK: - Voice Output (Text-to-Speech)
    
    func speak(_ text: String) {
        // Stop any current speech
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        
        // Strip markdown formatting for cleaner speech
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
        
        // Ensure audio session is set for playback
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
        
        isSpeaking = true
        synthesizer.speak(utterance)
    }
    
    func stopSpeaking() {
        synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
    }
}

// MARK: - AVSpeechSynthesizer Delegate

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
