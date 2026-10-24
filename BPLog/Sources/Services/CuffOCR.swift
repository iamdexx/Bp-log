import Vision
import UIKit

/// Reads systolic / diastolic / pulse off a photo of a home cuff display.
/// Home monitors show three big numbers top to bottom: SYS, DIA, PULSE.
/// We pick the integer tokens, sort by vertical position and sanity-check the ranges.
enum CuffOCR {
    struct Result: Equatable {
        var systolic: Int
        var diastolic: Int
        var pulse: Int?
    }

    static func read(_ image: UIImage) async -> Result? {
        guard let cg = image.cgImage else { return nil }
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        let handler = VNImageRequestHandler(cgImage: cg, orientation: image.cgOrientation, options: [:])
        do { try handler.perform([request]) } catch { return nil }
        let observations = request.results ?? []
        return parse(observations)
    }

    static func parse(_ observations: [VNRecognizedTextObservation]) -> Result? {
        var tokens: [(value: Int, y: CGFloat, height: CGFloat)] = []
        for o in observations {
            guard let text = o.topCandidates(1).first?.string else { continue }
            let cleaned = text.replacingOccurrences(of: "O", with: "0").replacingOccurrences(of: "o", with: "0")
                .replacingOccurrences(of: "I", with: "1").replacingOccurrences(of: "l", with: "1")
            for part in cleaned.split(whereSeparator: { !$0.isNumber }) {
                if let v = Int(part), (30...260).contains(v) {
                    tokens.append((v, o.boundingBox.midY, o.boundingBox.height))
                }
            }
        }
        return pick(tokens.map { ($0.value, $0.y, $0.height) })
    }

    /// Exposed for tests: values with their normalized y (1 = top) and box height.
    static func pick(_ tokens: [(Int, CGFloat, CGFloat)]) -> Result? {
        guard tokens.count >= 2 else { return nil }
        // Big digits on the display are the readings; drop anything much smaller than the biggest token (dates, clock, memory slot).
        let maxH = tokens.map { $0.2 }.max() ?? 0
        let big = tokens.filter { $0.2 >= maxH * 0.45 }.sorted { $0.1 > $1.1 }
        guard big.count >= 2 else { return nil }
        let sys = big[0].0, dia = big[1].0
        guard (70...260).contains(sys), (40...160).contains(dia), sys > dia else { return nil }
        var pulse: Int? = nil
        if big.count >= 3, (30...220).contains(big[2].0) { pulse = big[2].0 }
        return Result(systolic: sys, diastolic: dia, pulse: pulse)
    }
}

private extension UIImage {
    var cgOrientation: CGImagePropertyOrientation {
        switch imageOrientation {
        case .up: return .up
        case .down: return .down
        case .left: return .left
        case .right: return .right
        case .upMirrored: return .upMirrored
        case .downMirrored: return .downMirrored
        case .leftMirrored: return .leftMirrored
        case .rightMirrored: return .rightMirrored
        @unknown default: return .up
        }
    }
}
