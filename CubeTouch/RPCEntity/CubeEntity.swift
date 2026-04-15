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
import SwiftUI
import simd

extension Entity {
    /// Create a collision box that takes in user input with the drag gesture.
    private func addBox(size: SIMD3<Float>, position: SIMD3<Float>) -> Entity {
        /// The new entity for the box.
        let box = Entity()

        // Enable user inputs.
        box.components.set(InputTargetComponent())

        // Enable collisions for the box.
        box.components.set(CollisionComponent(shapes: [.generateBox(size: size)], isStatic: true))

        // Set the position of the box from the position value.
        box.position = position

        return box
    }

    func initCollision() {
        let big: Float = 1E2
        let small: Float = 1E-2

        self.addChild(addBox(size: [big, big, small], position: [0, 0, -0.5 * big]))
        self.addChild(addBox(size: [big, big, small], position: [0, 0, +0.5 * big]))
        self.addChild(addBox(size: [big, small, big], position: [0, -0.5 * big, 0]))
        self.addChild(addBox(size: [big, small, big], position: [0, +0.5 * big, 0]))
        self.addChild(addBox(size: [small, big, big], position: [-0.5 * big, 0, 0]))
        self.addChild(addBox(size: [small, big, big], position: [+0.5 * big, 0, 0]))
    }
}

@Observable
class CubeHandler {
    struct CubeState: Identifiable, Sendable {
        let id: UUID
        var position: SIMD3<Float>
        var color: CubeColor
        var entity: Entity
    }

    var rootEntity = Entity()

    var cubeSpawnInterval = 10.0

    var cubes: [UUID: CubeState] = [:]
    private var despawnTasks: [UUID: Task<Void, Never>] = [:]

    var animationPlaybackController: AnimationPlaybackController? = nil

    struct SpawnCubeData: Codable, Sendable {
        var id: UUID
        var position: SIMD3<Float>
        var color: CubeColor
    }

    func spawnCube(_ payload: SpawnCubeData) -> RPCResult {
        guard cubes[payload.id] == nil else {
            return RPCResult("Cube with id \(payload.id) already exists")
        }
        print("Spawning cube with id: \(payload.id), position: \(payload.position), color: \(payload.color)")

        let mesh = MeshResource.generateBox(size: 0.1)
        let material = SimpleMaterial(color: payload.color.uiColor, roughness: 0.4, isMetallic: false)
        let model = ModelEntity(mesh: mesh, materials: [material])

        model.name = "cube-\(payload.id.uuidString)"
        model.setPosition(payload.position, relativeTo: nil)
        model.components.set(InputTargetComponent())
        model.components.set(CollisionComponent(shapes: [.generateBox(size: .init(x: 0.1, y: 0.1, z: 0.1))]))

        model.setScale(SIMD3<Float>(x: 0.0001, y: 0.0001, z: 0.0001), relativeTo: nil)
        rootEntity.addChild(model)

        animationPlaybackController = model.move(
            to: Transform(scale: .one, rotation: model.orientation, translation: model.position),
            relativeTo: nil,
            duration: cubeSpawnInterval,
            timingFunction: .default
        )

        cubes[payload.id] = .init(
            id: payload.id,
            position: payload.position,
            color: payload.color,
            entity: model
        )

        print("Cube spawned: \(payload.id)")

        return RPCResult()
    }

    struct DespawnCubeData: Codable, Sendable {
        var id: UUID
    }

    func despawnCube(_ payload: DespawnCubeData) -> RPCResult {
        if let state = cubes.removeValue(forKey: payload.id) {
            state.entity.removeFromParent()
            despawnTasks[payload.id]?.cancel()
            despawnTasks.removeValue(forKey: payload.id)
        }
        return RPCResult()
    }

    struct TouchCubeData: Codable, Sendable {
        var id: UUID
        var playerId: Int
    }

    func resetCubes() -> RPCResult {
        rootEntity.children.removeAll()
        cubes.removeAll()
        despawnTasks.values.forEach { $0.cancel() }
        despawnTasks.removeAll()
        return RPCResult()
    }
}

struct CubeEntity: RPCEntity {
    static let codingKey = "cube"

    enum BroadcastMethod: RPCBroadcastMethod {
        typealias Handler = CubeHandler

        case despawnCube(Handler.DespawnCubeData)
        case resetCubes

        func execute(on handler: CubeHandler) -> RPCResult {
            switch self {
                case .despawnCube(let payload):
                    return handler.despawnCube(payload)
                case .resetCubes:
                    return handler.resetCubes()
            }
        }

        enum CodingKeys: CodingKey {
            case despawnCube
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
                            color: payload.color,
                        )
                    )
            }
        }

        enum CodingKeys: CodingKey {
            case spawnCube
        }
    }
}
