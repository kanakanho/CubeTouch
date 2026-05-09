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
                .font(.system(size: 40, weight: .bold, design: .default))

            HStack(spacing: 80) {
                VStack(alignment: .leading) {
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
                }
                
                if !appModel.scores.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("スコア")
                            .font(.title3)
                            .fontWeight(.semibold)
                        
                        HStack(alignment: .bottom) {
                            Text("自身のスコア: ")
                                .font(.system(size: 40, weight: .bold, design: .default))
                            Text("\(appModel.scores[appModel.myPlayerId, default: 0])")
                                .font(.system(size: 40, weight: .bold, design: .default))
                                .foregroundColor(.orange)
                            Text("pt")
                                .font(.system(size: 28, weight: .bold, design: .default))
                                .foregroundColor(.orange)
                        }
                        
                        ForEach(appModel.scores.keys.sorted(), id: \.self) { playerId in
                            if playerId != appModel.myPlayerId {
                                let score = appModel.scores[playerId, default: 0]
                                HStack(alignment: .bottom) {
                                    Text("\(playerId): ")
                                        .font(.system(size: 40, weight: .bold, design: .default))
                                    Text("\(score)")
                                        .font(.system(size: 40, weight: .bold, design: .default))
                                        .foregroundColor(.mint)
                                    Text("pt")
                                        .font(.system(size: 28, weight: .bold, design: .default))
                                        .foregroundColor(.mint)
                                }
                            }
                        }
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
                "ゲーム中 (共通ターゲットキューブを取り合い中)"
            case .ended:
                "ゲーム終了"
        }
    }
}

#Preview(windowStyle: .automatic) {
    ContentView()
        .environment(AppModel())
}
