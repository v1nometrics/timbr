// SPDX-License-Identifier: MPL-2.0
import Foundation

public struct TasteVector: Codable, Hashable, Sendable {
    public var values: [Double]

    public init(_ values: [Double]) {
        self.values = values.map { min(max($0, -1.0), 1.0) }
    }

    public func toSimpleTaste() -> SimpleTasteControls {
        let g: (Int) -> Double = { idx in idx < values.count ? values[idx] * 6.0 : 0.0 }
        return SimpleTasteControls(bassDB: g(0), warmthDB: g(1), presenceDB: g(2), airDB: g(3))
    }
}

public struct PairwiseComparison: Codable, Hashable, Sendable {
    public let candidateA: TasteVector
    public let candidateB: TasteVector
    public let winnerIsA: Bool

    public init(candidateA: TasteVector, candidateB: TasteVector, winnerIsA: Bool) {
        self.candidateA = candidateA
        self.candidateB = candidateB
        self.winnerIsA = winnerIsA
    }
}

public final class PairwiseGPTrainer: Sendable {
    public let dimensions: Int
    public let lengthscale: Double

    public init(dimensions: Int = 4, lengthscale: Double = 0.75) {
        self.dimensions = dimensions
        self.lengthscale = lengthscale
    }

    private func kernel(_ x1: [Double], _ x2: [Double]) -> Double {
        var sq = 0.0
        for i in 0..<min(x1.count, x2.count) {
            let d = (x1[i] - x2[i]) / lengthscale
            sq += d * d
        }
        return exp(-0.5 * sq)
    }

    public func proposeNextPair(history: [PairwiseComparison], seed: UInt64 = 42) -> (TasteVector, TasteVector) {
        var grid: [TasteVector] = []
        var state = seed &+ UInt64(history.count * 7919)
        func nextUniform() -> Double {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return Double((state >> 33) & 0xFFFF) / 65535.0 * 2.0 - 1.0
        }

        grid.append(TasteVector([0, 0, 0, 0]))
        for d in 0..<dimensions {
            var pos = [Double](repeating: 0, count: dimensions)
            var neg = [Double](repeating: 0, count: dimensions)
            pos[d] = 0.5; neg[d] = -0.5
            grid.append(TasteVector(pos))
            grid.append(TasteVector(neg))
        }
        for _ in 0..<48 {
            grid.append(TasteVector((0..<dimensions).map { _ in nextUniform() }))
        }

        let best = estimateBest(history: history, candidates: grid)
        if history.isEmpty {
            return (TasteVector([0.33, 0.0, 0.25, 0.17]), TasteVector([-0.25, 0.25, -0.17, 0.33]))
        }

        var bestChallenger = grid[1]
        var bestScore = -Double.infinity
        for cand in grid {
            let mu = scorePoint(cand.values, history: history)
            var minDist = Double.infinity
            for h in history {
                let da = zip(cand.values, h.candidateA.values).map { ($0 - $1) * ($0 - $1) }.reduce(0, +)
                let db = zip(cand.values, h.candidateB.values).map { ($0 - $1) * ($0 - $1) }.reduce(0, +)
                minDist = min(minDist, min(da, db))
            }
            let eubo = mu + 0.85 * sqrt(minDist)
            if eubo > bestScore && zip(cand.values, best.values).map({ abs($0 - $1) }).reduce(0, +) > 0.2 {
                bestScore = eubo
                bestChallenger = cand
            }
        }
        return (best, bestChallenger)
    }

    public func estimateBest(history: [PairwiseComparison], candidates: [TasteVector]? = nil) -> TasteVector {
        guard !history.isEmpty else { return TasteVector([Double](repeating: 0, count: dimensions)) }
        var pool = candidates ?? []
        if pool.isEmpty {
            for h in history {
                pool.append(h.candidateA)
                pool.append(h.candidateB)
            }
            for h in history {
                let win = h.winnerIsA ? h.candidateA.values : h.candidateB.values
                for d in 0..<dimensions {
                    var step = win
                    step[d] = min(max(step[d] + 0.16, -1.0), 1.0)
                    pool.append(TasteVector(step))
                    step[d] = min(max(win[d] - 0.16, -1.0), 1.0)
                    pool.append(TasteVector(step))
                }
            }
        }
        return pool.max(by: { scorePoint($0.values, history: history) < scorePoint($1.values, history: history) })
            ?? TasteVector([Double](repeating: 0, count: dimensions))
    }

    private func scorePoint(_ x: [Double], history: [PairwiseComparison]) -> Double {
        var score = 0.0
        for h in history {
            let win = h.winnerIsA ? h.candidateA.values : h.candidateB.values
            let lose = h.winnerIsA ? h.candidateB.values : h.candidateA.values
            score += kernel(x, win) - 0.65 * kernel(x, lose)
        }
        return score
    }
}
