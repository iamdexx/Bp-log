import SwiftUI

@main
struct BPLogWatchApp: App {
    @StateObject private var link = PhoneLink.shared
    var body: some Scene {
        WindowGroup { WatchHomeView().environmentObject(link) }
    }
}
