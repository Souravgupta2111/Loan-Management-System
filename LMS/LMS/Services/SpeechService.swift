//
//  SpeechService.swift
//  LMS
//
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
                // Activate the audio session off the main thread to avoid the
                // "UI unresponsiveness if called on the main thread" warnings.
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
    
    /// Speech recognition reports normal lifecycle events (end of speech, no
    /// speech detected, cancellation from `endAudio`/`cancel`) as errors. These
    /// are expected and must not be shown to the user as failures.
    private func isBenignRecognitionError(_ error: NSError) -> Bool {
        // kAFAssistantErrorDomain codes seen during normal operation:
        //   203  = "Retry" / no speech detected
        //   216  = recognition request was canceled (we called cancel/endAudio)
        //   1101 = local speech recognition service issue (transient)
        //   1110 = no speech detected
        if error.domain == "kAFAssistantErrorDomain" {
            return [203, 216, 1101, 1110, 0].contains(error.code)
        }
        // NSURLErrorDomain cancellation.
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

        // Force SERVER-BASED recognition. The log "kLSRErrorDomain 300 — Failed
        // to initialize recognizer" means the LOCAL (on-device) recognizer could
        // not start — this is the norm on the iOS Simulator and on devices that
        // haven't downloaded the offline speech model. Server-based recognition
        // sidesteps that broken daemon (it needs a network connection, which the
        // app already requires). Setting this to false is what makes the mic work
        // on the Simulator.
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

                // Distinguish benign end-of-speech / cancellation errors (which
                // fire during completely normal use — e.g. the user pauses, or we
                // call endAudio) from real failures. Surfacing the benign ones as
                // a scary "voice input unavailable" banner is what made the mic
                // look broken. We only show an error for genuine failures.
                if let error = error {
                    let nsError = error as NSError
                    print("⚠️ Recognition ended: \(nsError.domain) \(nsError.code) — \(error.localizedDescription)")

                    if !self.isBenignRecognitionError(nsError) {
                        #if targetEnvironment(simulator)
                        // SFSpeechRecognizer cannot initialize reliably in the iOS
                        // Simulator (kLSRErrorDomain 300). Apple limitation, not an
                        // app bug — voice input works on a real device.
                        self.speechError = "Voice input isn't supported in the iOS Simulator. Please test on a real device."
                        #else
                        self.speechError = "Voice input is unavailable right now. Please check your connection and try again."
                        #endif
                    }
                    // Tear down quietly either way so the mic button doesn't stick "on".
                    self.stopListening()
                } else if isFinal {
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
