import UIKit

final class AppWindow: UIWindow {}

/// Launch arguments: `-state <id>`, `-kind channel|group`, `-demo 1`.
struct LaunchOptions {
    let state: String
    let demo: Bool

    static let current: LaunchOptions = {
        let args = ProcessInfo.processInfo.arguments
        func value(_ name: String) -> String? {
            guard let i = args.firstIndex(of: name), i + 1 < args.count else { return nil }
            return args[i + 1]
        }
        return LaunchOptions(state: value("-state") ?? "list.before", demo: value("-demo") == "1")
    }()
}

final class App: NSObject, UINavigationControllerDelegate, UIGestureRecognizerDelegate {
    static let shared = App()

    private(set) var window: UIWindow!
    private(set) var navigation: UINavigationController!
    private(set) var overlay: UIView!
    private(set) var chatList: ChatListController!
    let indicatorLayer = PassthroughView()

    func start(window: UIWindow) {
        self.window = window
        let chatList = ChatListController()
        self.chatList = chatList
        let nav = UINavigationController(rootViewController: chatList)
        nav.setNavigationBarHidden(true, animated: false)
        nav.delegate = self
        nav.interactivePopGestureRecognizer?.delegate = self
        self.navigation = nav
        window.rootViewController = nav
        // Never black: iOS 26 rounds the corners of a sliding screen, and whatever is behind shows there.
        self.setSeamColor(Theme.ChatList.background)

        let overlay = PassthroughContainerView(frame: window.bounds)
        overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        window.addSubview(overlay)
        self.overlay = overlay

        self.indicatorLayer.frame = window.bounds
        self.indicatorLayer.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        window.addSubview(self.indicatorLayer)
        TouchIndicator.shared.hostView = self.indicatorLayer

        DispatchQueue.main.async {
            MainActor.assumeIsolated { StateLauncher.apply(LaunchOptions.current) }
        }
    }

    /// Keep the overlay containers above whatever UIKit adds to the window (presented sheets live in their own
    /// transition views).
    func bringOverlaysToFront() {
        self.window.bringSubviewToFront(self.overlay)
        self.window.bringSubviewToFront(self.indicatorLayer)
    }

    func push(_ vc: UIViewController, animated: Bool = true) {
        self.navigation.pushViewController(vc, animated: animated)
    }

    func popToRoot(animated: Bool = true) {
        self.navigation.popToRootViewController(animated: animated)
    }

    func pop(animated: Bool = true) {
        self.navigation.popViewController(animated: animated)
    }

    /// Where modal screens are presented from (the top of the stack).
    var presenter: UIViewController {
        var vc: UIViewController = self.navigation
        while let p = vc.presentedViewController { vc = p }
        return vc
    }

    // MARK: - Transition seams

    static func background(of vc: UIViewController?) -> UIColor {
        return vc?.view.backgroundColor ?? Theme.ChatList.background
    }

    /// The colour behind a push/pop: the side that is not a chat (whose wallpaper would look wrong as a seam), else
    /// the outgoing screen's. Chat list ↔ chat: white; chat ↔ profile: the profile's blocks colour.
    static func seamColor(from: UIViewController?, to: UIViewController) -> UIColor {
        guard let from else { return self.background(of: to) }
        let fromChat = from is ChatController
        let toChat = to is ChatController
        if fromChat && !toChat { return self.background(of: to) }
        return self.background(of: from)
    }

    /// Window, navigation view and (during a transition) its container all take the seam colour.
    func setSeamColor(_ color: UIColor) {
        self.window?.backgroundColor = color
        self.navigation?.view.backgroundColor = color
    }

    func navigationController(_ navigationController: UINavigationController, willShow viewController: UIViewController, animated: Bool) {
        let coordinator = navigationController.transitionCoordinator
        let color = App.seamColor(from: coordinator?.viewController(forKey: .from), to: viewController)
        self.setSeamColor(color)
        coordinator?.containerView.backgroundColor = color
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        return self.navigation.viewControllers.count > 1
    }
}

/// Lets touches through except on its own interactive subviews (toasts, menus).
final class PassthroughContainerView: UIView {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let view = super.hitTest(point, with: event)
        return view === self ? nil : view
    }
}
