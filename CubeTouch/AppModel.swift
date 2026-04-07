//
//  AppModel.swift
//  CubeTouch
//
//  Created by kanakanho on 2026/04/06.
//

import Foundation
import ImmersiveRPCKit
import Observation
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
    var growDuration: TimeInterval = 12
    var displayDuration: TimeInterval = 2

    var gameState: GameHandler.GameState { gameHandler.gameState }
    var gameStartedAt: Date? { gameHandler.gameStartedAt }
    var playerColors: [Int: String] { gameHandler.playerColors }
    var currentPlayerColorName: String { playerColors[myPlayerId] ?? "red" }
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

        let assignedColors = makePlayerColorAssignments()
        let payload = GameHandler.GameStartData(
            playerColors: assignedColors,
            startedAt: Date(),
            durationSeconds: gameDuration
        )
        rpcModel.run(syncAll: CubeEntity.request(.resetCubes))
        rpcModel.run(syncAll: ScoreEntity.request(.resetScore))
        rpcModel.run(syncAll: GameEntity.request(.startGame(payload)))
        
        print("game started")

        let firstCube = CubeHandler.SpawnCubeData(
            id: UUID(),
            position: randomCubePosition(),
            colorName: assignedColors[startCoordinatorPeerId ?? myPlayerId] ?? "red",
            spawnTime: Date()
        )
        rpcModel.run(transforming: .all, CubeEntity.self, .spawnCube(firstCube))
        
        print("cube spawned")
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
        guard let cube = cubes[cubeId] else {
            return
        }
        guard cube.colorName == currentPlayerColorName else {
            return
        }

        guard cubeHandler.canAcceptTouch(cubeId) else {
            return
        }

        rpcModel.run(syncAll: CubeEntity.request(.touchCube(.init(id: cubeId, playerId: myPlayerId))))
        rpcModel.run(syncAll: CubeEntity.request(.despawnCube(.init(id: cubeId))))
        rpcModel.run(syncAll: ScoreEntity.request(.addScore(.init(playerId: myPlayerId))))
        spawnCubeAfterTouch(with: currentPlayerColorName)
    }

    func despawnCube(id: UUID) {
        rpcModel.run(syncAll: CubeEntity.request(.despawnCube(.init(id: id))))
    }

    func spawnCubeAfterTouch(with colorName: String) {
        let data = CubeHandler.SpawnCubeData(
            id: UUID(),
            position: randomCubePosition(),
            colorName: colorName,
            spawnTime: Date()
        )
        rpcModel.run(transforming: .all, CubeEntity.self, .spawnCube(data))
    }

    func checkGameTimeout(now: Date = Date()) {
        guard gameState == .running, let startedAt = gameStartedAt else {
            return
        }
        if now.timeIntervalSince(startedAt) >= gameDuration {
            finishGame()
        }
    }

    private func randomCubePosition() -> SIMD3<Float> {
        SIMD3<Float>(
            Float.random(in: -0.8...0.8),
            Float.random(in: 0.1...1.6),
            Float.random(in: -0.8 ... 0.8)
        )
    }

    private func makePlayerColorAssignments() -> [Int: String] {
        let colors = ["red", "blue", "green", "yellow", "orange", "purple"]
        var result: [Int: String] = [:]

        for (index, peerId) in sortedPeerIDs.enumerated() {
            result[peerId] = colors[index % colors.count]
        }

        return result
    }
}
