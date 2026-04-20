//
//  ImmersiveView.swift
//  CubeTouch
//
//  Created by kanakanho on 2026/04/06.
//

import ARKit
import RealityKit
import RealityKitContent
import SwiftUI

struct ImmersiveView: View {
    @Environment(AppModel.self) private var appModel
    @State private var collisionSubscriptions: [EventSubscription] = []

    @State var session = ARKitSession()
    @State var handTracking = HandTrackingProvider()
    @State var sceneReconstruction = SceneReconstructionProvider()
    @State var latestRightIndexFingerPos: SIMD3<Float> = .init()
    @State var latestLeftIndexFingerPos: SIMD3<Float> = .init()

    @State var rightSensor = Entity()
    @State var leftSensor = Entity()

    @State var sceneMeshRootEntity = Entity()
    @State var sceneMeshEntities: [UUID: ModelEntity] = [:]

    var body: some View {
        RealityView { content in
            do {
                let scene: Entity = try await Entity(named: "Scene", in: realityKitContentBundle)
                if let ball = scene.findEntity(named: "Sphere") {
                    rightSensor = ball.clone(recursive: false)
                    leftSensor = ball.clone(recursive: false)

                    rightSensor.name = "hand-sensor-right"
                    leftSensor.name = "hand-sensor-left"

                    content.add(rightSensor)
                    content.add(leftSensor)
                }
            } catch {
                print("Failed to load scene: \(error)")
            }

            appModel.cubeHandler.rootEntity.initCollision()
            content.add(appModel.cubeHandler.rootEntity)

            content.add(appModel.sceneMeshRootEntity)

            await configureHandCollisionSensors(content: content)
        }
        .task {
            do {
                try await session.run([handTracking, sceneReconstruction])

                await processHandUpdates()
            } catch {
                print("Failed to start session: \(error)")
            }
        }
        .task(priority: .low) {
            await processReconstructionUpdates()
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                appModel.checkGameTimeout()
            }
        }
    }

    private func configureHandCollisionSensors(content: RealityViewContent) async {
        guard collisionSubscriptions.isEmpty else { return }

        setupHandSensor(content: content)
    }

    private func setupHandSensor(content: RealityViewContent) {
        let sub = content.subscribe(to: CollisionEvents.Began.self) { event in
            handleCollision(event)
        }
        collisionSubscriptions.append(sub)
    }

    private func handleCollision(_ event: CollisionEvents.Began) {
        // 衝突した相手が cube-UUID 形式の名前を持っているかチェック
        if let cubeID = extractCubeID(from: event.entityA.name) ?? extractCubeID(from: event.entityB.name) {
            appModel.touchCube(cubeId: cubeID)
        }
    }

    private func extractCubeID(from name: String) -> UUID? {
        guard name.hasPrefix("cube-") else { return nil }
        return UUID(uuidString: String(name.dropFirst(5)))
    }

    @MainActor
    func processHandUpdates() async {
        for await update in handTracking.anchorUpdates {
            switch update.event {
                case .updated:
                    if appModel.gameHandler.gameState != .running { continue }

                    let anchor = update.anchor

                    guard anchor.isTracked else { continue }

                    let fingerTipIndex = anchor.handSkeleton?.joint(.indexFingerTip)
                    let originFromWrist = anchor.originFromAnchorTransform
                    let wristFromIndex = fingerTipIndex?.anchorFromJointTransform
                    let originFromIndex = originFromWrist * wristFromIndex!

                    if anchor.chirality == .left {
                        let leftHandAnchor = anchor
                        guard let handSkeletonAnchorTransform = leftHandAnchor.handSkeleton?.joint(.indexFingerTip).anchorFromJointTransform else { return }
                        latestLeftIndexFingerPos = (leftHandAnchor.originFromAnchorTransform * handSkeletonAnchorTransform).position
                        leftSensor.setTransformMatrix(originFromIndex, relativeTo: nil)
                    } else if anchor.chirality == .right {
                        let rightHandAnchor = anchor
                        guard let handSkeletonAnchorTransform = rightHandAnchor.handSkeleton?.joint(.indexFingerTip).anchorFromJointTransform else { return }
                        latestRightIndexFingerPos = (rightHandAnchor.originFromAnchorTransform * handSkeletonAnchorTransform).position
                        rightSensor.setTransformMatrix(originFromIndex, relativeTo: nil)
                    }
                default:
                    break
            }
        }
    }

    @MainActor
    func processReconstructionUpdates() async {
        for await update in sceneReconstruction.anchorUpdates {
            let meshAnchor = update.anchor

            guard let shape = try? await ShapeResource.generateStaticMesh(from: meshAnchor) else { continue }
            switch update.event {
                case .added:
                    let cyanMaterial: SimpleMaterial = .init(color: .cyan, isMetallic: false)
//                    let mesh = await MeshResource(shape: shape)
                    let sceneMeshEntity = ModelEntity(mesh: .generateBox(size: 0.0), materials: [cyanMaterial])

                    sceneMeshEntity.transform = Transform(matrix: meshAnchor.originFromAnchorTransform)
                    sceneMeshEntity.collision = CollisionComponent(shapes: [shape], isStatic: true)
                    sceneMeshEntity.components.set(InputTargetComponent())

                    // mode が dynamic でないと物理演算が適用されない
                    sceneMeshEntity.physicsBody = PhysicsBodyComponent(mode: .dynamic)

                    sceneMeshEntities[meshAnchor.id] = sceneMeshEntity
                    appModel.sceneMeshRootEntity.addChild(sceneMeshEntity)
                case .updated:
                    guard let sceneMeshEntity = sceneMeshEntities[meshAnchor.id] else { continue }
                    sceneMeshEntity.transform = Transform(matrix: meshAnchor.originFromAnchorTransform)
                    sceneMeshEntity.collision?.shapes = [shape]
//                    sceneMeshEntity.model?.mesh = await MeshResource(shape: shape)
                case .removed:
                    sceneMeshEntities[meshAnchor.id]?.removeFromParent()
                    sceneMeshEntities.removeValue(forKey: meshAnchor.id)
            }
        }
    }
}

#Preview(immersionStyle: .mixed) {
    ImmersiveView()
        .environment(AppModel())
}
