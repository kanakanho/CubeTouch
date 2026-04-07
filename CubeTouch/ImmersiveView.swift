//
//  ImmersiveView.swift
//  CubeTouch
//
//  Created by kanakanho on 2026/04/06.
//

import RealityKit
import RealityKitContent
import SwiftUI

struct ImmersiveView: View {
    @Environment(AppModel.self) private var appModel

    @State private var rootEntity = Entity()
    @State private var entityByID: [UUID: ModelEntity] = [:]
    @State private var despawnTaskByID: [UUID: Task<Void, Never>] = [:]
    @State private var trackingSession: SpatialTrackingSession?
    @State private var collisionSubscriptions: [EventSubscription] = []

    var body: some View {
        RealityView { content in
            content.add(rootEntity)

            await configureHandCollisionSensors(content: content)
        }
        .onAppear {
            syncCubes(with: appModel.cubes)
        }
        .onChange(of: cubeIDs) {
            syncCubes(with: appModel.cubes)
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                appModel.checkGameTimeout()
            }
        }
        .onDisappear {
            cancelAllDespawnTasks()
        }
    }

    private var cubeIDs: Set<UUID> {
        Set(appModel.cubes.keys)
    }

    private func syncCubes(with cubes: [UUID: CubeHandler.CubeState]) {
        for (cubeID, cube) in cubes where entityByID[cubeID] == nil {
            let model = makeCubeEntity(cube: cube)
            entityByID[cubeID] = model
            rootEntity.addChild(model)
            scheduleDespawn(for: cube)
        }

        let activeIDs = Set(cubes.keys)
        let removedIDs = entityByID.keys.filter { !activeIDs.contains($0) }
        for id in removedIDs {
            despawnTaskByID[id]?.cancel()
            despawnTaskByID.removeValue(forKey: id)
            entityByID.removeValue(forKey: id)?.removeFromParent()
        }
    }

    private func scheduleDespawn(for cube: CubeHandler.CubeState) {
        despawnTaskByID[cube.id]?.cancel()

        let elapsed = max(0, Date().timeIntervalSince(cube.spawnTime))
        let remaining = max(0, appModel.growDuration + appModel.displayDuration - elapsed)
        let cubeID = cube.id

        despawnTaskByID[cubeID] = Task {
            try? await Task.sleep(for: .seconds(remaining))
            guard !Task.isCancelled else {
                return
            }
            appModel.despawnCube(id: cubeID)
        }
    }

    private func cancelAllDespawnTasks() {
        for (_, task) in despawnTaskByID {
            task.cancel()
        }
        despawnTaskByID.removeAll()
    }

    private func configureHandCollisionSensors(content: RealityViewContent) async {
        if trackingSession == nil {
            let session = SpatialTrackingSession()
            let configuration = SpatialTrackingSession.Configuration(tracking: [.hand])
            _ = await session.run(configuration)
            trackingSession = session
        }

        guard collisionSubscriptions.isEmpty else {
            return
        }

        let rightSensor = makeHandSensor(name: "hand-sensor-right")
        let rightAnchor = AnchorEntity(.hand(.right, location: .indexFingerTip), trackingMode: .predicted)
        rightAnchor.addChild(rightSensor)
        rootEntity.addChild(rightAnchor)

        let leftSensor = makeHandSensor(name: "hand-sensor-left")
        let leftAnchor = AnchorEntity(.hand(.left, location: .indexFingerTip), trackingMode: .predicted)
        leftAnchor.addChild(leftSensor)
        rootEntity.addChild(leftAnchor)

        let rightSubscription = content.subscribe(to: CollisionEvents.Began.self, on: rightSensor) { event in
            handleCollision(event)
        }
        let leftSubscription = content.subscribe(to: CollisionEvents.Began.self, on: leftSensor) { event in
            handleCollision(event)
        }

        collisionSubscriptions.append(rightSubscription)
        collisionSubscriptions.append(leftSubscription)
    }

    private func handleCollision(_ event: CollisionEvents.Began) {
        if let cubeID = cubeID(from: event.entityA.name) {
            appModel.touchCube(cubeId: cubeID)
            return
        }

        if let cubeID = cubeID(from: event.entityB.name) {
            appModel.touchCube(cubeId: cubeID)
        }
    }

    private func makeCubeEntity(cube: CubeHandler.CubeState) -> ModelEntity {
        let mesh = MeshResource.generateBox(size: 1.0)
        let material = SimpleMaterial(color: color(for: cube.colorName), roughness: 0.4, isMetallic: false)
        let entity = ModelEntity(mesh: mesh, materials: [material])
        entity.name = "cube-\(cube.id.uuidString)"
        entity.position = cube.position
        let elapsed = max(0, Date().timeIntervalSince(cube.spawnTime))
        let clampedGrowDuration = max(0.0001, appModel.growDuration)
        let progress = min(1, elapsed / clampedGrowDuration)
        let currentScale = Float(0.01 + (1.0 - 0.01) * progress)
        entity.scale = .one * currentScale
        entity.components.set(InputTargetComponent())
        entity.components.set(CollisionComponent(shapes: [.generateBox(size: [1, 1, 1])]))

        let remaining = max(0, clampedGrowDuration - elapsed)
        if remaining > 0 {
            var targetTransform = entity.transform
            targetTransform.scale = .one
            entity.move(
                to: targetTransform,
                relativeTo: entity.parent,
                duration: remaining,
                timingFunction: .linear
            )
        }

        return entity
    }

    private func makeHandSensor(name: String) -> Entity {
        let sensor = Entity()
        sensor.name = name
        sensor.components.set(CollisionComponent(shapes: [.generateSphere(radius: 0.02)], mode: .trigger, filter: .default))
        return sensor
    }

    private func cubeID(from name: String) -> UUID? {
        guard name.hasPrefix("cube-") else {
            return nil
        }
        return UUID(uuidString: String(name.dropFirst(5)))
    }

    private func color(for colorName: String) -> UIColor {
        switch colorName.lowercased() {
            case "red":
                return .red
            case "blue":
                return .blue
            case "green":
                return .green
            case "yellow":
                return .yellow
            case "orange":
                return .orange
            case "purple":
                return .purple
            case "white":
                return .white
            default:
                return .gray
        }
    }
}

#Preview(immersionStyle: .mixed) {
    ImmersiveView()
        .environment(AppModel())
}
