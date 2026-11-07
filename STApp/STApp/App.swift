import SwiftUI

@main
struct STAppApp: App {
    @StateObject private var store = QuestionStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
        }
    }
}
