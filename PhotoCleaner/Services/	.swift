import CoreGraphics
import CoreML
import UIKit

final class ScreenshotSourceModelRunner {
    static let shared = ScreenshotSourceModelRunner()

    private let inputHeight = 384
    private let inputWidth = 192
    private let mean: [Float] = [0.485, 0.456, 0.406]
    private let std: [Float] = [0.229, 0.224, 0.225]
    private let topRatio: CGFloat = 0.58
    private let bottomRatio: CGFloat = 0.38
    private let weights: [Double] = [0.3, 0.4, 0.3]

    private lazy var model: MLModel? = {
        guard let url = Bundle.main.url(forResource: "ScreenshotSourceClassifier", withExtension: "mlmodelc") else {
            return nil
        }
        let config = MLModelConfiguration()
        config.computeUnits = .all
        return try? MLModel(contentsOf: url, configuration: config)
    }()

    private init() {}

    func classify(cgImage: CGImage) -> ScreenshotCategory? {
        guard let model else { return nil }

        let full = CGRect(x: 0, y: 0, width: CGFloat(cgImage.width), height: CGFloat(cgImage.height))
        let top = CGRect(
            x: 0,
            y: 0,
            width: CGFloat(cgImage.width),
            height: CGFloat(max(1, Int(CGFloat(cgImage.height) * topRatio)))
        )
        let bottomHeight = max(1, Int(CGFloat(cgImage.height) * bottomRatio))
        let bottom = CGRect(
            x: 0,
            y: CGFloat(cgImage.height - bottomHeight),
            width: CGFloat(cgImage.width),
            height: CGFloat(bottomHeight)
        )

        let crops = [full, top, bottom]
        var fused: [String: Double] = [:]
        for (idx, crop) in crops.enumerated() {
            guard let probabilities = predictProbabilities(model: model, cgImage: cgImage, crop: crop) else {
                continue
            }
            let weight = weights[idx]
            for (label, probability) in probabilities {
                fused[label, default: 0] += probability * weight
            }
        }

        guard let best = fused.max(by: { $0.value < $1.value })?.key else { return nil }
        return ScreenshotCategory(rawValue: best)
    }

    private func predictProbabilities(model: MLModel, cgImage: CGImage, crop: CGRect) -> [String: Double]? {
        guard
            let array = makeInputArray(cgImage: cgImage, crop: crop),
            let provider = try? MLDictionaryFeatureProvider(dictionary: [
                "image": MLFeatureValue(multiArray: array)
            ]),
            let output = try? model.prediction(from: provider),
            let probabilityName = model.modelDescription.predictedProbabilitiesName,
            let raw = output.featureValue(for: probabilityName)?.dictionaryValue
        else {
            return nil
        }

        var probabilities: [String: Double] = [:]
        probabilities.reserveCapacity(raw.count)
        for (key, value) in raw {
            guard let label = key as? String else { continue }
            probabilities[label] = value.doubleValue
        }
        return probabilities
    }

    private func makeInputArray(cgImage: CGImage, crop: CGRect) -> MLMultiArray? {
        guard let cropped = cgImage.cropping(to: crop.integral) else { return nil }
        let bytesPerPixel = 4
        let bytesPerRow = inputWidth * bytesPerPixel
        var pixels = [UInt8](repeating: 0, count: inputHeight * bytesPerRow)
        guard
            let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
            let context = CGContext(
                data: &pixels,
                width: inputWidth,
                height: inputHeight,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ),
            let array = try? MLMultiArray(shape: [1, 3, NSNumber(value: inputHeight), NSNumber(value: inputWidth)], dataType: .float32)
        else {
            return nil
        }
        context.interpolationQuality = .high
        context.draw(cropped, in: CGRect(x: 0, y: 0, width: inputWidth, height: inputHeight))

        for y in 0..<inputHeight {
            for x in 0..<inputWidth {
                let pixel = y * bytesPerRow + x * bytesPerPixel
                let r = Float(pixels[pixel]) / 255.0
                let g = Float(pixels[pixel + 1]) / 255.0
                let b = Float(pixels[pixel + 2]) / 255.0
                let offset = y * inputWidth + x
                array[offset] = NSNumber(value: (r - mean[0]) / std[0])
                array[inputHeight * inputWidth + offset] = NSNumber(value: (g - mean[1]) / std[1])
                array[2 * inputHeight * inputWidth + offset] = NSNumber(value: (b - mean[2]) / std[2])
            }
        }
        return array
    }
}
