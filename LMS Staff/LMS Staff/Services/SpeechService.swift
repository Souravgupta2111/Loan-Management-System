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
    private var speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-IN"))
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
    

    
    private func startAudioSession() throws {
        let audioSession = AVAudioSession.sharedInstance()
        // Use .playAndRecord to handle both STT and TTS without category switching,
        // which crashes the iOS Simulator audio driver (Abandoning I/O cycle).
        try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
    }
    
    private func startRecognition() throws {
        recognitionTask?.cancel()
        self.recognitionTask = nil
        
        // Re-initialize the recognizer on every run. 
        // On iOS Simulators, the background speechd daemon frequently crashes 
        // leaving the existing instance permanently broken (Failed to initialize).
        self.speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-IN"))

        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            throw NSError(domain: "SpeechService", code: 2, userInfo: [NSLocalizedDescriptionKey: "Speech recognizer is not available right now. Check your network connection."])
        }

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()

        guard let request = recognitionRequest else {
            throw NSError(domain: "SpeechService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to create recognition request"])
        }

        request.shouldReportPartialResults = true

        // Force SERVER-BASED recognition. "kLSRErrorDomain 300 — Failed to
        // initialize recognizer" means the LOCAL (on-device) recognizer could not
        // start — the norm on the iOS Simulator and on devices without the offline
        // model downloaded. Server-based recognition avoids that broken daemon and
        // is what makes the mic work on the Simulator (it needs network, which the
        // app already requires).
        request.requiresOnDeviceRecognition = false
        
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
                
                if let error = error {
                    print("⚠️ Recognition ended: \(error.localizedDescription)")
                    // Do NOT call stopListening() here! B-easy explicitly avoids this
                    // to prevent simulator CoreAudio crashes.
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
        
        // Do NOT deactivate audio session here. 
        // TTS will likely follow immediately, and rapid activation/deactivation 
        // causes "Abandoning I/O cycle because reconfig pending" on simulators.
    }
    
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
        
        // No need to switch audio session category here.
        // It is already set to .playAndRecord in startAudioSession().
        // Switching back and forth crashes the simulator driver.
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
