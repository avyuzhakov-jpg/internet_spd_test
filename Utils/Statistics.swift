import Foundation

enum Statistics {

    /// Median of array. Returns nil if empty.
    static func median(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        let mid = sorted.count / 2

        if sorted.count % 2 == 0 {
            return (sorted[mid - 1] + sorted[mid]) / 2.0
        } else {
            return sorted[mid]
        }
    }

    /// Mean (average). Returns nil if empty.
    static func mean(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    /// Sample standard deviation (unbiased, N-1 in denominator).
    /// For jitter, sample deviation is often a good choice.
    static func sampleStandardDeviation(_ values: [Double]) -> Double? {
        guard values.count >= 2 else { return 0.0 } // jitter = 0 if only one sample
        guard let avg = mean(values) else { return nil }

        let variance = values
            .map { ($0 - avg) * ($0 - avg) }
            .reduce(0, +) / Double(values.count - 1)

        return sqrt(variance)
    }

    /// Convenience: calculates (pingMedian, jitterStdDev) for a list of ping samples in ms.
    static func pingAndJitter(from pingSamplesMs: [Double]) -> (pingMs: Double, jitterMs: Double)? {
        guard !pingSamplesMs.isEmpty else { return nil }
        guard let med = median(pingSamplesMs) else { return nil }
        let jitter = sampleStandardDeviation(pingSamplesMs) ?? 0.0
        return (med, jitter)
    }
}
