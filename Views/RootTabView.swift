import SwiftUI

struct RootTabView: View {
    var body: some View {
        TabView {
            SpeedTestView()
                .tabItem {
                    Label("Speed Test", systemImage: "speedometer")
                }

            LogsView()
                .tabItem {
                    Label("Logs", systemImage: "list.bullet")
                }
        }
    }
}
