import Foundation
import CoreGraphics

enum GamePhase: Equatable {
    case menu
    case playing
    case gameOver
}

enum EntityKind {
    case orb
    case hazard
}

struct LaneEntity: Identifiable, Equatable {
    let id: UUID
    var lane: Int
    var y: CGFloat
    var kind: EntityKind
    var collected: Bool = false
}

struct ParticleBurst: Identifiable, Equatable {
    let id: UUID
    var x: CGFloat
    var y: CGFloat
    var born: Date
}
