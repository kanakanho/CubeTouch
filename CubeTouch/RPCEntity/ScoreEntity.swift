//
//  ScoreEntity.swift
//  CubeTouch
//
//  Created by kanakanho on 2026/04/06.
//

import Foundation
import ImmersiveRPCKit
import Observation

@Observable
class ScoreHandler {
    var scores: [Int: Int] = [:]

    struct AddScoreData: Codable, Sendable {
        var playerId: Int
    }

    func addScore(_ payload: AddScoreData) -> RPCResult {
        scores[payload.playerId, default: 0] += 1
        return RPCResult()
    }

    func resetScore() -> RPCResult {
        scores.removeAll()
        return RPCResult()
    }
}

struct ScoreEntity: RPCEntity {
    static let codingKey = "score"

    typealias UnicastMethod = NoMethod<ScoreHandler>

    enum BroadcastMethod: RPCBroadcastMethod {
        typealias Handler = ScoreHandler

        case addScore(Handler.AddScoreData)
        case resetScore

        func execute(on handler: ScoreHandler) -> RPCResult {
            switch self {
                case .addScore(let payload):
                    return handler.addScore(payload)
                case .resetScore:
                    return handler.resetScore()
            }
        }

        enum CodingKeys: CodingKey {
            case addScore
            case resetScore
        }
    }
}
