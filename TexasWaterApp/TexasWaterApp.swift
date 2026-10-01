import SwiftUI
import UIKit

@main
struct TexasWaterApp: App {
    init() {
        UINavigationBar.appearance().largeTitleTextAttributes = [
            .foregroundColor: UIColor.label
        ]
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
