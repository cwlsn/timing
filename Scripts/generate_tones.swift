// Writes the eight original tones. Run: swift Scripts/generate_tones.swift Resources/Sounds
// Every tone ends in silence so it loops cleanly, and is under 30 seconds.
import AVFoundation

let rate = 44_100.0
struct Note { var at: Double, freq: Double, length: Double, gain: Double, decay: Double, partials: [(Double, Double)], bend = 0.0 }

func n(_ at: Double, _ freq: Double, _ length: Double = 1.2, gain: Double = 0.5, decay: Double = 4,
       partials: [(Double, Double)] = [(1, 1)], bend: Double = 0) -> Note {
    Note(at: at, freq: freq, length: length, gain: gain, decay: decay, partials: partials, bend: bend)
}

let bell = [(1.0, 1.0), (2.0, 0.6), (2.76, 0.4), (5.4, 0.2)], wood = [(1.0, 1.0), (3.9, 0.25)]
let square = [(1.0, 1.0), (3.0, 0.33), (5.0, 0.2)], soft = [(1.0, 1.0), (2.0, 0.25)]
let tones: [(String, Double, [Note])] = [
    ("daybreak", 8, (0..<8).map { n(Double($0) * 0.85, [392, 440, 523.25, 587.33, 659.25, 783.99, 880, 1046.5][$0], 1.6, decay: 2.5, partials: soft) }),
    ("marimba", 6, (0..<20).map { n(Double($0) * 0.26, [523.25, 659.25, 783.99, 659.25, 880][$0 % 5], 0.6, decay: 8, partials: wood) }),
    ("glass", 6, (0..<6).map { n(Double($0) * 0.9, [1567.98, 1318.5, 2093][$0 % 3], 1.2, gain: 0.4, decay: 4, partials: bell) }),
    ("pulse", 4, (0..<12).map { n(Double($0 / 3) + Double($0 % 3) * 0.18, 740, 0.14, decay: 1, partials: square) }),
    ("arcade", 4, (0..<28).map { n(Double($0) * 0.13, [329.63, 392, 493.88, 659.25, 587.33, 493.88, 440][$0 % 7], 0.11, gain: 0.35, decay: 3, partials: square) }),
    ("bell-tower", 8, (0..<4).map { n(Double($0) * 1.6, [329.63, 261.63, 293.66, 196][$0], 2.4, gain: 0.45, decay: 1.8, partials: bell) }),
    ("drift", 10, (0..<6).map { n(Double($0) * 1.4, [261.63, 329.63, 392, 493.88, 392, 329.63][$0], 2.6, gain: 0.35, decay: 0.8, partials: soft) }),
    ("siren", 4, (0..<4).map { n(Double($0), 620, 0.85, decay: 0.3, partials: square, bend: 500) }),
]

let folder = URL(filePath: CommandLine.arguments[1])
for (name, length, notes) in tones {
    var samples = [Double](repeating: 0, count: Int(length * rate))
    for note in notes {
        for (multiple, level) in note.partials {
            var phase = 0.0
            for i in 0..<Int(note.length * rate) where Int(note.at * rate) + i < samples.count {
                let t = Double(i) / rate
                let envelope = min(t / 0.008, 1) * exp(-note.decay * t) * min((note.length - t) / 0.03, 1)
                phase += 2 * .pi * (note.freq + note.bend * t / note.length) * multiple / rate
                samples[Int(note.at * rate) + i] += sin(phase) * level * envelope * note.gain
            }
        }
    }
    let peak = samples.map(abs).max()!
    let format = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 1)!
    let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count))!
    buffer.frameLength = buffer.frameCapacity
    for (i, value) in samples.enumerated() { buffer.floatChannelData![0][i] = Float(value / peak * 0.85) }
    let file = try AVAudioFile(
        forWriting: folder.appending(path: name + ".caf"),
        settings: [AVFormatIDKey: kAudioFormatLinearPCM, AVSampleRateKey: rate, AVNumberOfChannelsKey: 1,
                   AVLinearPCMBitDepthKey: 16, AVLinearPCMIsFloatKey: false, AVLinearPCMIsBigEndianKey: false])
    try file.write(from: buffer)
}
