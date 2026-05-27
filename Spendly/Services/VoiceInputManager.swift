import Foundation
import Speech
import AVFoundation

@MainActor
@Observable
final class VoiceInputManager {

    var transcript = ""
    var isListening = false
    var isAvailable = false
    var permissionGranted = false
    var errorMessage: String?

    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    private var silenceTimer: Timer?

    init() {
        updateLocale()
    }

    // MARK: - Locale

    func updateLocale() {
        let locale = speechLocale(for: AppPreferences.shared.language)
        speechRecognizer = SFSpeechRecognizer(locale: locale)
        isAvailable = speechRecognizer?.isAvailable ?? false
    }

    private func speechLocale(for language: AppLanguage) -> Locale {
        switch language {
        case .es: return Locale(identifier: "es-CO")
        case .en: return Locale(identifier: "en-US")
        case .de: return Locale(identifier: "de-DE")
        case .fr: return Locale(identifier: "fr-FR")
        case .pt: return Locale(identifier: "pt-BR")
        }
    }

    // MARK: - Permissions

    func requestPermissions() async -> Bool {
        let speechStatus = await withCheckedContinuation { cont in
            SFSpeechRecognizer.requestAuthorization { status in
                cont.resume(returning: status)
            }
        }

        guard speechStatus == .authorized else {
            errorMessage = "Permiso de reconocimiento de voz denegado."
            permissionGranted = false
            return false
        }

        let micStatus = await withCheckedContinuation { cont in
            AVAudioApplication.requestRecordPermission { granted in
                cont.resume(returning: granted)
            }
        }

        guard micStatus else {
            errorMessage = "Permiso de microfono denegado."
            permissionGranted = false
            return false
        }

        permissionGranted = true
        return true
    }

    // MARK: - Start / Stop

    func startListening() {
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            errorMessage = "Reconocimiento de voz no disponible."
            return
        }

        // Clean up previous session
        stopListening()

        transcript = ""
        errorMessage = nil

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        self.recognitionRequest = request

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor in
                guard let self else { return }

                if let result {
                    self.transcript = result.bestTranscription.formattedString
                    self.resetSilenceTimer()

                    if result.isFinal {
                        self.stopListening()
                    }
                }

                if let error, !self.transcript.isEmpty {
                    // Ignore errors if we already have a transcript
                    _ = error
                    self.stopListening()
                } else if let error, self.transcript.isEmpty {
                    self.errorMessage = "Error: \(error.localizedDescription)"
                    self.stopListening()
                }
            }
        }

        do {
            try audioEngine.start()
            isListening = true
        } catch {
            errorMessage = "No se pudo iniciar el microfono."
            cleanUp()
        }
    }

    func stopListening() {
        silenceTimer?.invalidate()
        silenceTimer = nil

        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        isListening = false
    }

    // MARK: - Silence Detection (2 seconds)

    private func resetSilenceTimer() {
        silenceTimer?.invalidate()
        silenceTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.stopListening()
            }
        }
    }

    private func cleanUp() {
        recognitionRequest = nil
        recognitionTask = nil
        isListening = false
    }
}
