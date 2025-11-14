import SwiftUI

@main
struct MyApp: App {
    @StateObject private var scoreStore = ScoreStore()
    
    var body: some Scene {
        WindowGroup {
            NavigationStack {
                TopView()
            }
            .environmentObject(scoreStore) //ここで全体に共有！
        }
    }
}

