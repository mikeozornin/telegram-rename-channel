import UIKit
import Display

/// Telegram's default day theme (`.dayClassic`, accent 0x0088ff), the values this prototype draws with.
/// Source: submodules/TelegramPresentationData/Sources/DefaultDayPresentationTheme.swift.
enum Theme {
    static let accent = UIColor(rgb: 0x0088ff)
    static let destructive = UIColor(rgb: 0xff3b30)

    // list (DefaultDayPresentationTheme.swift:472-537)
    enum List {
        static let blocksBackground = UIColor(rgb: 0xefeff4)
        static let plainBackground = UIColor(rgb: 0xffffff)
        static let itemBlocksBackground = UIColor(rgb: 0xffffff)
        static let primaryText = UIColor(rgb: 0x000000)
        static let secondaryText = UIColor(rgb: 0x8e8e93)
        static let highlight = UIColor(rgb: 0xe5e5ea)
        static let separator = UIColor(rgb: 0xc8c7cc)
        static let freeText = UIColor(rgb: 0x6d6d72)
        static let placeholder = UIColor(rgb: 0xc8c8ce)
        static let disabled = UIColor(rgb: 0xd0d0d0)
    }

    // chat list (DefaultDayPresentationTheme.swift:539-578)
    enum ChatList {
        static let background = UIColor(rgb: 0xffffff)
        static let separator = UIColor(rgb: 0xc8c7cc)
        static let title = UIColor(rgb: 0x000000)
        static let date = UIColor(rgb: 0x8e8e93)
        static let preview = UIColor(rgb: 0x8e8e93)
        static let author = UIColor(rgb: 0x000000)
        static let muteIcon = UIColor(rgb: 0xa7a7ad)
        static let unreadBadge = UIColor(rgb: 0x0088ff)
        static let unreadBadgeMuted = UIColor(rgb: 0xb6b6bb)
        static let pinnedBackground = UIColor(rgb: 0xf7f7f7)
        static let searchFill = UIColor(rgb: 0x000000, alpha: 0.06)
        static let searchPlaceholder = UIColor(rgb: 0x8e8e93)
    }

    // root navigation bar / tab bar (DefaultDayPresentationTheme.swift:412-443)
    enum Nav {
        static let accent = UIColor(rgb: 0x0088ff)
        static let primary = UIColor(rgb: 0x000000)
        static let secondary = UIColor(rgb: 0x787878)
        static let separator = UIColor(rgb: 0xc8c7cc)
    }
    enum Tab {
        static let icon = UIColor(rgb: 0x959595)
        static let selected = UIColor(rgb: 0x0088ff)
        static let text = UIColor(rgb: 0x000000, alpha: 0.8)
    }

    // context menu (DefaultDayPresentationTheme.swift:1043-1058)
    enum Menu {
        static let dim = UIColor(rgb: 0x000a26, alpha: 0.2)
        static let background = UIColor(rgb: 0xf9f9f9, alpha: 0.78)
        static let separator = UIColor(rgb: 0x3c3c43, alpha: 0.2)
        static let primary = UIColor(rgb: 0x000000)
        static let destructive = UIColor(rgb: 0xff3b30)
    }

    // chat bubbles, classic day (DefaultDayPresentationTheme.swift:587+)
    enum Bubble {
        static let incoming = UIColor(rgb: 0xffffff)
        static let outgoing = UIColor(rgb: 0xe1ffc7)
        static let incomingSecondary = UIColor(rgb: 0x77828c)
        static let outgoingSecondary = UIColor(rgb: 0x008c09, alpha: 0.8)
        static let incomingAccent = UIColor(rgb: 0x0088ff)
        static let outgoingAccent = UIColor(rgb: 0x00a700)
        static let service = UIColor(rgb: 0x000000, alpha: 0.2)
    }

    /// AvatarNode.swift:600-607, top/bottom gradient pairs.
    static let avatarGradients: [(UInt32, UInt32)] = [
        (0xff516a, 0xff885e),
        (0xffa85c, 0xffcd6a),
        (0x665fff, 0x82b1ff),
        (0x54cb68, 0xa0de7e),
        (0x4acccd, 0x00fcfd),
        (0x2a9ef1, 0x72d5fd),
        (0xd669ed, 0xe0a2f3)
    ]
}

func icon(_ name: String, _ color: UIColor) -> UIImage? {
    return generateTintedImage(image: UIImage(named: name), color: color)
}
