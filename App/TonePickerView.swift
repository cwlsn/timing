import AVFoundation
import SwiftUI

enum Tone {
    static let all = ["Daybreak", "Marimba", "Glass", "Pulse", "Arcade", "Bell Tower", "Drift", "Siren"]
    static func file(_ name: String) -> String { name.lowercased().replacing(" ", with: "-") + ".caf" }
    static func name(for file: String?) -> String { all.first { Self.file($0) == file } ?? "System default" }
}

/// A menu of tones. Choosing one plays it.
struct TonePicker: View {
    @Binding var tone: String?
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var player = TonePreviewPlayer()
    @State private var playing: String?
    @State private var preview: Task<Void, Never>?

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout(spacing: 12))
        layout {
            Text("Sound").accessibilityHidden(true)
            if !dynamicTypeSize.isAccessibilitySize { Spacer() }
            HStack(spacing: 8) {
                if let tone { previewButton(tone) }
                menu
            }
        }
        .font(.subheadline)
        .frame(minHeight: 44)
        .sensoryFeedback(.selection, trigger: tone)
        .onDisappear {
            preview?.cancel()
            Task { await player.stop() }
        }
    }

    private var menu: some View {
        Menu {
            Picker("Sound", selection: Binding(get: { tone }, set: { tone = $0; play($0) })) {
                Text("System default").tag(String?.none)
                ForEach(Tone.all, id: \.self) { Text($0).tag(String?.some(Tone.file($0))) }
            }
            .pickerStyle(.inline)
            .labelsHidden()
        } label: {
            Chip(isSelected: false) {
                Text(Tone.name(for: tone)).lineLimit(1).minimumScaleFactor(0.7)
                Image(systemName: "chevron.up.chevron.down").imageScale(.small).foregroundStyle(Color.quiet)
            }
        }
        .accessibilityLabel("Sound")
        .accessibilityValue(Tone.name(for: tone))
        .accessibilityIdentifier("tone-menu")
    }

    private func previewButton(_ tone: String) -> some View {
        let isPlaying = playing == tone
        return Button { play(isPlaying ? nil : tone) } label: {
            Image(systemName: isPlaying ? "stop.fill" : "play.fill")
                .font(.body)
                .contentTransition(.symbolEffect(.replace))
                .foregroundStyle(Color.accentText)
                .frame(width: 44, height: 44)
                .contentShape(.rect)
        }
        .buttonStyle(SpringyButtonStyle())
        .accessibilityLabel(isPlaying ? "Stop sound" : "Play sound")
    }

    /// Plays a tone, or stops when there is none.
    private func play(_ file: String?) {
        let previous = preview
        previous?.cancel()
        playing = file
        preview = Task {
            await previous?.value
            guard !Task.isCancelled else { return }
            guard let length = await player.play(file) else {
                playing = nil
                return await player.stop()
            }
            try? await Task.sleep(for: .seconds(length))
            guard !Task.isCancelled else { return }
            playing = nil
            await player.stop()
        }
    }
}

/// An actor because activating the audio session can block.
actor TonePreviewPlayer {
    private var player: AVAudioPlayer?

    /// Returns how long the tone lasts, or `nil` if there is nothing to play.
    func play(_ file: String?) -> TimeInterval? {
        stop()
        guard let file, let url = Bundle.main.url(forResource: file, withExtension: nil) else { return nil }
        // Playback is heard even in Silent mode, like the alarm itself.
        try? AVAudioSession.sharedInstance().setCategory(.playback)
        try? AVAudioSession.sharedInstance().setActive(true)
        player = try? AVAudioPlayer(contentsOf: url)
        guard let player, player.play() else { return nil }
        return player.duration
    }

    func stop() {
        guard let player else { return }
        player.stop()
        self.player = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
