import SwiftUI

@main
struct DenonRemoteApp: App {
    @StateObject private var receiver = Receiver()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            TabView {
                RemoteView()
                    .tabItem { Label("Remote", systemImage: "dot.radiowaves.left.and.right") }
                LevelsView()
                    .tabItem { Label("Levels", systemImage: "slider.vertical.3") }
                SoundView()
                    .tabItem { Label("Sound", systemImage: "waveform") }
                SignalView()
                    .tabItem { Label("Signal", systemImage: "arrow.left.arrow.right") }
                BackendView()
                    .tabItem { Label("Backend", systemImage: "terminal") }
            }
            .environmentObject(receiver)
            .preferredColorScheme(.dark)
            .onChange(of: scenePhase) { phase in
                // The receiver's control port is shared with other tools (Evo32, scripts),
                // so let go of it whenever the app is not on screen.
                if phase == .active {
                    if receiver.status != .connected && receiver.status != .connecting {
                        receiver.connect()
                    }
                } else if phase == .background {
                    receiver.disconnect()
                }
            }
        }
    }
}
