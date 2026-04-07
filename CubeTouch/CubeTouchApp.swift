//
//  CubeTouchApp.swift
//  CubeTouch
//
//  Created by kanakanho on 2026/04/06.
//

import ImmersiveRPCKit
import SwiftUI

@main
struct CubeTouchApp: App {

    @State private var appModel = AppModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appModel)
                .onAppear {
                    appModel.startNetworking()
                }
                .onDisappear {
                    appModel.stopNetworking()
                }
        }

        ImmersiveSpace(id: appModel.immersiveSpaceID) {
            SharedCoordinateImmersiveView(
                rpcModel: appModel.rpcModel,
                coordinateTransforms: appModel.coordinateTransforms
            ) {
                ImmersiveView()
                    .environment(appModel)
                    .onAppear {
                        appModel.immersiveSpaceState = .open
                    }
                    .onDisappear {
                        appModel.immersiveSpaceState = .closed
                    }
            }
        }
        .immersionStyle(selection: .constant(.mixed), in: .mixed)
    }
}
