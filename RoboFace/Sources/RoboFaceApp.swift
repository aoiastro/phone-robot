import SwiftUI

@main
struct RoboFaceApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var viewModel = RobotViewModel()

    var body: some Scene {
        WindowGroup {
            RobotScreenView(viewModel: viewModel)
                .task {
                    await viewModel.startIfNeeded()
                }
        }
        .onChange(of: scenePhase) { _, newPhase in
            viewModel.handleScenePhase(newPhase)
        }
    }
}

