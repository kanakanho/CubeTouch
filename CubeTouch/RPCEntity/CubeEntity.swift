//
//  CubeEntity.swift
//  CubeTouch
//
//  Created by kanakanho on 2026/04/06.
//

import Foundation
import ImmersiveRPCKit
import Observation
import RealityKit
import simd

@Observable
class CubeHandler {
    struct CubeState: Identifiable, Sendable {
        let id: UUID
        var position: SIMD3<Float>
        var colorName: String
        var spawnTime: Date
    }

    var cubes: [UUID: CubeState] = [:]
    var processedTouchCubeIDs: Set<UUID> = []
    var processedDespawns: Set<UUID> = []

    func canAcceptTouch(_ cubeId: UUID) -> Bool {
        !processedTouchCubeIDs.contains(cubeId)
    }

    struct SpawnCubeData: Codable, Sendable {
        var id: UUID
        var position: SIMD3<Float>
        var colorName: String
        var spawnTime: Date
    }

    func spawnCube(_ payload: SpawnCubeData) -> RPCResult {
        cubes[payload.id] = .init(
            id: payload.id,
            position: payload.position,
            colorName: payload.colorName,
            spawnTime: payload.spawnTime
        )
        processedDespawns.remove(payload.id)
        return RPCResult()
    }

    struct DespawnCubeData: Codable, Sendable {
        var id: UUID
    }

    func despawnCube(_ payload: DespawnCubeData) -> RPCResult {
        guard !processedDespawns.contains(payload.id) else {
            return RPCResult("Cube already despawned")
        }
        processedDespawns.insert(payload.id)
        cubes.removeValue(forKey: payload.id)
        return RPCResult()
    }

    struct TouchCubeData: Codable, Sendable {
        var id: UUID
        var playerId: Int
    }

    func touchCube(_ payload: TouchCubeData) -> RPCResult {
        guard !processedTouchCubeIDs.contains(payload.id) else {
            return RPCResult("Cube already touched")
        }
        processedTouchCubeIDs.insert(payload.id)
        return RPCResult()
    }

    func resetCubes() -> RPCResult {
        cubes.removeAll()
        processedTouchCubeIDs.removeAll()
        processedDespawns.removeAll()
        return RPCResult()
    }
}

struct CubeEntity: RPCEntity {
    static let codingKey = "cube"

    enum BroadcastMethod: RPCBroadcastMethod {
        typealias Handler = CubeHandler

        case despawnCube(Handler.DespawnCubeData)
        case touchCube(Handler.TouchCubeData)
        case resetCubes

        func execute(on handler: CubeHandler) -> RPCResult {
            switch self {
                case .despawnCube(let payload):
                    return handler.despawnCube(payload)
                case .touchCube(let payload):
                    return handler.touchCube(payload)
                case .resetCubes:
                    return handler.resetCubes()
            }
        }

        enum CodingKeys: CodingKey {
            case despawnCube
            case touchCube
            case resetCubes
        }
    }

    enum UnicastMethod: RPCTransformableUnicastMethod {
        typealias Handler = CubeHandler

        case spawnCube(Handler.SpawnCubeData)

        func execute(on handler: CubeHandler) -> RPCResult {
            switch self {
                case .spawnCube(let payload):
                    return handler.spawnCube(payload)
            }
        }

        func applying(affineMatrix: simd_float4x4) -> Self {
            switch self {
                case .spawnCube(let payload):
                    let transformed = affineMatrix * simd_float4(payload.position, 1)
                    return .spawnCube(
                        .init(
                            id: payload.id,
                            position: SIMD3<Float>(transformed.x, transformed.y, transformed.z),
                            colorName: payload.colorName,
                            spawnTime: payload.spawnTime
                        )
                    )
            }
        }

        enum CodingKeys: CodingKey {
            case spawnCube
        }
    }
}
