//
//  GameEntity.swift
//  CubeTouch
//
//  Created by kanakanho on 2026/04/06.
//

import Foundation
import ImmersiveRPCKit
import Observation

@Observable
class GameHandler {
    enum GameState {
        case waiting
        case running
        case ended
    }

    var gameState: GameState = .waiting
    var gameStartedAt: Date?
    var gameDuration: TimeInterval = 60

    struct GameStartData: Codable, Sendable {
        var startedAt: Date
        var durationSeconds: TimeInterval
    }

    func startGame(_ payload: GameStartData) -> RPCResult {
        guard gameState != .running else {
            return RPCResult("Game is already running")
        }

        gameStartedAt = payload.startedAt
        gameDuration = payload.durationSeconds
        gameState = .running
        return RPCResult()
    }

    func endGame() -> RPCResult {
        gameState = .ended
        return RPCResult()
    }
}

struct GameEntity: RPCEntity {
    static let codingKey = "game"

    typealias UnicastMethod = NoMethod<GameHandler>

    enum BroadcastMethod: RPCBroadcastMethod {
        typealias Handler = GameHandler

        case startGame(Handler.GameStartData)
        case endGame

        func execute(on handler: GameHandler) -> RPCResult {
            switch self {
                case .startGame(let payload):
                    return handler.startGame(payload)
                case .endGame:
                    return handler.endGame()
            }
        }

        enum CodingKeys: CodingKey {
            case startGame
            case endGame
        }
    }
}
