import Foundation
import SwiftUI
import Combine

@MainActor
final class GameEngine: ObservableObject {
    @Published var phase: GamePhase = .menu
    @Published var lane: Int = 1
    @Published var score: Int = 0
    @Published var highScore: Int = UserDefaults.standard.integer(forKey: "sparklane.highScore")
    @Published var entities: [LaneEntity] = []
    @Published var bursts: [ParticleBurst] = []
    @Published var speed: CGFloat = 220
    @Published var pulse = false
    @Published var shake: CGFloat = 0

    private var lastTick: Date?
    private var spawnCooldown: TimeInterval = 0
    private var distanceScoreAcc: CGFloat = 0
    private var tickTask: Task<Void, Never>?
    private let laneCount = 3
    private let playerYRatio: CGFloat = 0.82

    var playerY: CGFloat { playerYRatio }

    func start() {
        score = 0
        lane = 1
        entities = []
        bursts = []
        speed = 220
        spawnCooldown = 0.4
        distanceScoreAcc = 0
        lastTick = nil
        shake = 0
        phase = .playing
        pulse = true
        startLoop()
    }

    func returnToMenu() {
        stopLoop()
        phase = .menu
        entities = []
        bursts = []
        pulse = false
    }

    func moveLeft() {
        guard phase == .playing else { return }
        lane = max(0, lane - 1)
    }

    func moveRight() {
        guard phase == .playing else { return }
        lane = min(laneCount - 1, lane + 1)
    }

    func stopLoop() {
        tickTask?.cancel()
        tickTask = nil
    }

    private func startLoop() {
        stopLoop()
        tickTask = Task { [weak self] in
            let frame: UInt64 = 16_666_667
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: frame)
                await MainActor.run {
                    self?.tick(now: Date())
                }
            }
        }
    }

    private func tick(now: Date) {
        guard phase == .playing else { return }
        let dt: CGFloat
        if let last = lastTick {
            dt = CGFloat(now.timeIntervalSince(last))
        } else {
            dt = 1.0 / 60.0
        }
        lastTick = now
        let clamped = min(dt, 0.05)

        speed = min(480, speed + clamped * 8)
        spawnCooldown -= TimeInterval(clamped)
        if spawnCooldown <= 0 {
            spawn()
            let base = max(0.28, 0.85 - Double(speed - 220) / 500)
            spawnCooldown = base + Double.random(in: 0...0.18)
        }

        distanceScoreAcc += clamped * speed * 0.02
        if distanceScoreAcc >= 1 {
            let add = Int(distanceScoreAcc)
            score += add
            distanceScoreAcc -= CGFloat(add)
        }

        var next: [LaneEntity] = []
        for var entity in entities {
            entity.y += (speed * clamped) / 900
            if entity.y > 1.15 { continue }

            let nearPlayer = abs(entity.y - playerYRatio) < 0.045 && entity.lane == lane
            if nearPlayer && !entity.collected {
                switch entity.kind {
                case .orb:
                    entity.collected = true
                    score += 10
                    bursts.append(ParticleBurst(id: UUID(), x: laneX(entity.lane), y: entity.y, born: now))
                    continue
                case .hazard:
                    gameOver()
                    return
                }
            }
            next.append(entity)
        }
        entities = next
        bursts.removeAll { now.timeIntervalSince($0.born) > 0.55 }
        if shake > 0 {
            shake = max(0, shake - clamped * 8)
        }
    }

    private func spawn() {
        let lanePick = Int.random(in: 0..<laneCount)
        let kind: EntityKind = Double.random(in: 0...1) < 0.62 ? .hazard : .orb
        // Occasionally spawn a second entity in another lane for pressure
        entities.append(LaneEntity(id: UUID(), lane: lanePick, y: -0.08, kind: kind))
        if speed > 300, Double.random(in: 0...1) < 0.35 {
            let other = (0..<laneCount).filter { $0 != lanePick }.randomElement() ?? 0
            entities.append(LaneEntity(id: UUID(), lane: other, y: -0.18, kind: .hazard))
        }
    }

    private func gameOver() {
        stopLoop()
        phase = .gameOver
        pulse = false
        shake = 1
        if score > highScore {
            highScore = score
            UserDefaults.standard.set(highScore, forKey: "sparklane.highScore")
        }
    }

    func laneX(_ lane: Int) -> CGFloat {
        let spacing: CGFloat = 1.0 / CGFloat(laneCount + 1)
        return spacing * CGFloat(lane + 1)
    }
}
