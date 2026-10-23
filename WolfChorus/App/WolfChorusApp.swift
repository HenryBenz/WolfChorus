import SwiftUI
import UIKit

@main
struct WolfChorusApp: App {
    @UIApplicationDelegateAdaptor(WolfChorusDelegate.self) private var delegate
    @StateObject private var save: SaveService
    @StateObject private var audio = AudioService()
    @StateObject private var haptics = HapticsService()
    @StateObject private var preferences = Preferences()
    @StateObject private var purchase: PurchaseService
    @StateObject private var router = AppRouter()

    init() {
        let save = SaveService()
        _save = StateObject(wrappedValue: save)
        _purchase = StateObject(wrappedValue: PurchaseService(save: save))
    }

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environmentObject(save)
                .environmentObject(audio)
                .environmentObject(haptics)
                .environmentObject(preferences)
                .environmentObject(purchase)
                .environmentObject(router)
        }
    }
}

final class WolfChorusDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        .portrait
    }
}
