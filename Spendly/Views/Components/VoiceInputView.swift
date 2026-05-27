import SwiftUI

struct VoiceInputView: View {

    let onParsed: (ParsedExpense) -> Void
    let onCancel: () -> Void

    @State private var voiceManager = VoiceInputManager()
    @State private var hasPermission = false
    @State private var showPermissionDenied = false
    @State private var pulseScale: CGFloat = 1.0
    @State private var preferences = AppPreferences.shared

    private let teal = Color.fingetherPrimary

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Mic with pulsing rings
            ZStack {
                // Pulsing rings (only when listening)
                if voiceManager.isListening {
                    ForEach(0..<3, id: \.self) { i in
                        Circle()
                            .stroke(teal.opacity(0.3 - Double(i) * 0.1), lineWidth: 2)
                            .frame(width: 90 + CGFloat(i) * 30, height: 90 + CGFloat(i) * 30)
                            .scaleEffect(pulseScale)
                    }
                }

                // Mic button
                Button {
                    handleMicTap()
                } label: {
                    ZStack {
                        Circle()
                            .fill(voiceManager.isListening ? teal : teal.opacity(0.1))
                            .frame(width: 80, height: 80)
                            .shadow(color: teal.opacity(voiceManager.isListening ? 0.3 : 0.1), radius: 12, y: 4)

                        Image(systemName: voiceManager.isListening ? "mic.fill" : "mic")
                            .font(.system(size: 32))
                            .foregroundStyle(voiceManager.isListening ? .white : teal)
                    }
                }
                .sensoryFeedback(.impact, trigger: voiceManager.isListening)
            }
            .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: pulseScale)
            .onAppear {
                pulseScale = 1.3
            }

            // Status text
            if voiceManager.isListening {
                Text(voiceManager.transcript.isEmpty ? "Escuchando..." : voiceManager.transcript)
                    .font(.system(size: 18, weight: voiceManager.transcript.isEmpty ? .regular : .medium))
                    .foregroundStyle(voiceManager.transcript.isEmpty ? .secondary : Color(.label))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .animation(.easeInOut(duration: 0.2), value: voiceManager.transcript)
            } else if !voiceManager.transcript.isEmpty {
                // Finished listening — show result
                VStack(spacing: 12) {
                    Text(voiceManager.transcript)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(Color(.label))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)

                    Button {
                        let parsed = VoiceExpenseParser.parse(
                            text: voiceManager.transcript,
                            language: preferences.language
                        )
                        onParsed(parsed)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark")
                            Text("Usar esto")
                        }
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(teal)
                        .clipShape(Capsule())
                        .shadow(color: teal.opacity(0.2), radius: 6, y: 3)
                    }

                    Button {
                        voiceManager.transcript = ""
                        voiceManager.startListening()
                    } label: {
                        Text("Intentar de nuevo")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(teal)
                    }
                }
            } else {
                Text("Toca el microfono y di tu gasto")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Error
            if let error = voiceManager.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(Color.fingetherDanger)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            // Permission denied
            if showPermissionDenied {
                VStack(spacing: 8) {
                    Text("Activa el permiso de microfono en Configuracion")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Text("Abrir Configuracion")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(teal)
                    }
                }
                .padding(.horizontal, 24)
            }

            Spacer()

            // Examples
            VStack(spacing: 6) {
                Text("Ejemplos:")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Group {
                    Text("\"Gaste 30 mil en el supermercado\"")
                    Text("\"Uber 25 mil\"")
                    Text("\"Almuerzo 18 mil quinientos\"")
                }
                .font(.caption)
                .foregroundStyle(.tertiary)
            }
            .padding(.bottom, 8)

            // Cancel
            Button {
                voiceManager.stopListening()
                onCancel()
            } label: {
                Text("Cancelar")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 16)
        }
        .task {
            voiceManager.updateLocale()
        }
    }

    private func handleMicTap() {
        if voiceManager.isListening {
            voiceManager.stopListening()
        } else {
            Task {
                let granted = await voiceManager.requestPermissions()
                if granted {
                    showPermissionDenied = false
                    voiceManager.startListening()
                } else {
                    showPermissionDenied = true
                }
            }
        }
    }
}
