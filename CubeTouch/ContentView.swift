//
//  ContentView.swift
//  CubeTouch
//
//  Created by kanakanho on 2026/04/06.
//

import ImmersiveRPCKit
import SwiftUI

struct ContentView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("CubeTouch")
                .font(.largeTitle)
                .fontWeight(.semibold)

            Text(statusText)
                .font(.headline)

            HStack(spacing: 12) {
                Button("ゲーム開始") {
                    appModel.beginGame()
                }
                .disabled(appModel.gameState == .running)

                Button("ゲーム終了") {
                    appModel.finishGame()
                }
                .disabled(appModel.gameState != .running)
            }

            ToggleImmersiveSpaceButton()

            if !appModel.scores.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("スコア")
                        .font(.title3)
                        .fontWeight(.semibold)
                    ForEach(appModel.scores.keys.sorted(), id: \.self) { playerId in
                        let score = appModel.scores[playerId, default: 0]
                        let colorName = appModel.playerColors[playerId] ?? "-"
                        Text("Player \(playerId): \(score) (\(colorName))")
                    }
                }
            }

            Divider()

            TransformationMatrixPreparationView(
                rpcModel: appModel.rpcModel,
                coordinateTransforms: appModel.coordinateTransforms
            )
            .disabled(appModel.immersiveSpaceState != .open)
        }
        .padding(64)
    }

    private var statusText: String {
        switch appModel.gameState {
            case .waiting:
                "待機中"
            case .running:
                "ゲーム中 (あなたの色: \(appModel.currentPlayerColorName))"
            case .ended:
                "ゲーム終了"
        }
    }
}

#Preview(windowStyle: .automatic) {
    ContentView()
        .environment(AppModel())
}
