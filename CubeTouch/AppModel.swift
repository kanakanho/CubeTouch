//
//  AppModel.swift
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

/// Maintains app-wide state
@MainActor
@Observable
class AppModel {
    let immersiveSpaceID = "ImmersiveSpace"

    enum ImmersiveSpaceState {
        case closed
        case inTransition
        case open
    }

    var immersiveSpaceState = ImmersiveSpaceState.closed

    var gameDuration: TimeInterval {
        get { gameHandler.gameDuration }
        set { gameHandler.gameDuration = newValue }
    }

    var gameState: GameHandler.GameState { gameHandler.gameState }
    var gameStartedAt: Date? { gameHandler.gameStartedAt }
    var cubes: [UUID: CubeHandler.CubeState] { cubeHandler.cubes }
    var scores: [Int: Int] { scoreHandler.scores }

    let sendExchangeDataWrapper = ExchangeDataWrapper()
    let receiveExchangeDataWrapper = ExchangeDataWrapper()
    let mcPeerIDUUIDWrapper = MCPeerIDUUIDWrapper()
    let coordinateTransforms = CoordinateTransforms()

    private(set) var peerManager: PeerManager
    private(set) var rpcModel: RPCModel

    let gameHandler: GameHandler
    let cubeHandler: CubeHandler
    let scoreHandler: ScoreHandler

    var sceneMeshRootEntity: Entity = Entity()

    init() {
        gameHandler = GameHandler()
        cubeHandler = CubeHandler()
        scoreHandler = ScoreHandler()

        peerManager = PeerManager(
            sendExchangeDataWrapper: sendExchangeDataWrapper,
            receiveExchangeDataWrapper: receiveExchangeDataWrapper,
            mcPeerIDUUIDWrapper: mcPeerIDUUIDWrapper,
            serviceType: "CubeGame"
        )

        rpcModel = RPCModel(
            sendExchangeDataWrapper: sendExchangeDataWrapper,
            receiveExchangeDataWrapper: receiveExchangeDataWrapper,
            mcPeerIDUUIDWrapper: mcPeerIDUUIDWrapper,
            entities: [
                RPCEntityRegistration<GameEntity>(handler: gameHandler),
                RPCEntityRegistration<CubeEntity>(handler: cubeHandler),
                RPCEntityRegistration<ScoreEntity>(handler: scoreHandler),
                RPCEntityRegistration<CoordinateTransformEntity>(handler: coordinateTransforms),
            ]
        )

        rpcModel.isLogging = true
    }

    var myPlayerId: Int {
        mcPeerIDUUIDWrapper.mine.hash
    }

    private var sortedPeerIDs: [Int] {
        Array(Set([myPlayerId] + mcPeerIDUUIDWrapper.standby.map(\.hash))).sorted()
    }

    private var startCoordinatorPeerId: Int? {
        sortedPeerIDs.first
    }

    private var isStartCoordinator: Bool {
        startCoordinatorPeerId == myPlayerId
    }

    private let sharedTargetCubeColor: CubeColor = .cyan

    func startNetworking() {
        peerManager.start()
    }

    func stopNetworking() {
        peerManager.stop()
    }

    func beginGame() {
        guard gameState != .running else {
            return
        }
        guard isStartCoordinator else {
            return
        }

        print("start game")

        let payload = GameHandler.GameStartData(
            startedAt: Date(),
            durationSeconds: gameDuration
        )
        rpcModel.run(syncAll: CubeEntity.request(.resetCubes))
        rpcModel.run(syncAll: ScoreEntity.request(.resetScore))
        rpcModel.run(syncAll: GameEntity.request(.startGame(payload)))

        print("game started")

        spawnSharedTargetCube()

        print("initial shared target cube spawned")
    }

    func finishGame() {
        rpcModel.run(syncAll: GameEntity.request(.endGame))
    }

    func addScore(playerId: Int) {
        rpcModel.run(syncAll: ScoreEntity.request(.addScore(.init(playerId: playerId))))
    }

    func resetScore() {
        rpcModel.run(syncAll: ScoreEntity.request(.resetScore))
    }

    func touchCube(cubeId: UUID) {
        guard gameState == .running else {
            return
        }
        guard cubes[cubeId] != nil else {
            return
        }

        despawnCube(id: cubeId)
        rpcModel.run(syncAll: ScoreEntity.request(.addScore(.init(playerId: myPlayerId))))
        spawnSharedTargetCube()
    }

    func despawnCube(id: UUID) {
        rpcModel.run(syncAll: CubeEntity.request(.despawnCube(.init(id: id, playerId: myPlayerId))))
    }

    func spawnCubeAfterTouch(with color: CubeColor) {
        let data = CubeHandler.SpawnCubeData(
            id: UUID(),
            position: safeSpawnPosition(),
            color: color,
        )
        rpcModel.run(transforming: .all, CubeEntity.self, .spawnCube(data))
    }

    func spawnSharedTargetCube() {
        spawnCubeAfterTouch(with: sharedTargetCubeColor)
    }

    func checkGameTimeout(now: Date = Date()) {
        guard gameState == .running, let startedAt = gameStartedAt else {
            return
        }
        if now.timeIntervalSince(startedAt) >= gameDuration {
            finishGame()
        }
    }

    func safeSpawnPosition() -> SIMD3<Float> {
        let maxSpawnAttempts = 8

        for _ in 0..<maxSpawnAttempts {
            let candidate = randomCubePosition()

            let radomXZ: SIMD3<Float> = .init(
                candidate.x,
                2.0,
                candidate.z
            )

            // カメラ → 候補位置 の方向
            let direction = normalize(candidate - radomXZ)
            let distance = length(candidate - radomXZ)

            // SceneMeshのCollisionComponentに対してRaycast
            let rayOrigin = radomXZ
            let hits = sceneMeshRootEntity.scene?.raycast(
                origin: rayOrigin,
                direction: direction,
                length: distance,
                query: .nearest,
                mask: .all
            )

            // ヒットなし = 視線が通っている = 安全
            if hits?.isEmpty == true {
                return candidate
            }

            print("💥💥💥💥💥💥💥💥💥💥💥💥💥💥💥💥💥💥💥💥💥💥💥💥💥💥💥💥💥💥💥💥💥💥💥💥💥💥💥💥💥💥💥💥💥💥💥💥💥💥💥💥💥💥💥💥💥💥💥💥💥💥💥💥💥")
        }

        return randomCubePosition()
    }

    private func randomCubePosition() -> SIMD3<Float> {
        SIMD3<Float>(
            Float.random(in: -2.4...2.4),
            Float.random(in: 0.1...1.6),
            Float.random(in: -2.4...2.4)
        )
    }

}
