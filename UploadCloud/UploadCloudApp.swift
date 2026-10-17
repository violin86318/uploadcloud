import SwiftUI

@main
struct UploadCloudApp: App {
    var body: some Scene {
        WindowGroup {
            TabView {
                HistoryView()
                    .tabItem { Label("已传文件", systemImage: "clock.arrow.circlepath") }

                ContentView()
                    .tabItem { Label("设置", systemImage: "gearshape") }
            }
            .frame(minWidth: 700, minHeight: 450)
        }
    }
}
