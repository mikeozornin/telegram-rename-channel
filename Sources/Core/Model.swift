import UIKit

enum PeerKind {
    case channel
    case group
    case user
}

/// A chat in the list. All data is fixed (no randomness) so every state and screenshot is reproducible.
struct Chat {
    let id: String
    let originalTitle: String
    let kind: PeerKind
    let memberCount: Int?
    let colorIndex: Int
    let initials: String
    let author: String?
    let preview: String
    let time: String
    let unread: Int
    let muted: Bool
    let pinned: Bool
    let read: Bool          // outgoing read checks (private chats)
    var avatarImage: String? = nil  // a photo in Resources/Avatars instead of the letter avatar
}

final class Store {
    static let shared = Store()

    let kind: PeerKind
    private(set) var customNames: [String: String] = [:]
    private var observers: [(id: UUID, fn: () -> Void)] = []

    static let targetId = "beavers"
    static let lenaId = "pixel"
    static let designersId = "designers"
    static let mikeId = "mikestream"
    /// The latest post of the product owner's channel (the row shows its start, newlines flattened).
    static let mikePost = "This is genius.\n\nhttps://maxxbench.unlap.ai/research/why-maxxbench/\n\nThe guys took the tasks from deepswe, a popular coding benchmark, slightly reworded them and ran the tests again.\n\nSome models lost half their score. That's indirect evidence the benchmark had been optimized for.\n\nThey also noticed that models try to guess how a task will be checked and play to it: they tailor answers to the expected tests even when that contradicts the task. Or they figure nobody can check it honestly anyway, and simplify the solution.\n\nDeepSeek is a genius, I love it!\n\nOnce it remembered it had an OpenRouter key (the one the tests run through) and, reasoning \u{201C}this is ethically gray, but network is allowed\u{201D}, went off to consult other models and copy their solutions. Once it even replaced its own correct answer with a wrong copied one. Just like people."

    private init() {
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "-kind"), i + 1 < args.count, args[i + 1] == "group" {
            self.kind = .group
        } else {
            self.kind = .channel
        }
        self.customNames[Store.lenaId] = "Lena Smith — Design Reviews & Portfolio Teardowns 🔥"
    }

    static let demoCustomName = "Pete Ivanov — Productivity"

    var target: Chat { return self.chat(Store.targetId)! }

    lazy var chats: [Chat] = {
        let isGroup = self.kind == .group
        return [
            Chat(id: Store.targetId,
                 originalTitle: isGroup ? "Beavers & Productivity Chat" : "Beavers & Productivity",
                 kind: self.kind, memberCount: isGroup ? 1204 : 12480, colorIndex: 1, initials: "BP",
                 author: isGroup ? "Max" : nil,
                 preview: isGroup ? "Does anyone track sleep with a ring? Mine says I rested 4 hours and I feel great 🦫" : "Habit trackers don’t fail. We just stop opening them. Three tricks that kept me going for a year 🦫",
                 time: "21:58", unread: isGroup ? 12 : 4, muted: false, pinned: false, read: false),
            Chat(id: Store.designersId, originalTitle: "Designers", kind: .group, memberCount: 8, colorIndex: 2, initials: "D",
                 author: "Anya", preview: "👀 look what I found", time: "21:40", unread: 3, muted: false, pinned: false, read: false),
            Chat(id: "mom", originalTitle: "Mom", kind: .user, memberCount: nil, colorIndex: 0, initials: "M",
                 author: nil, preview: "Call me when you’re free, nothing urgent ❤️", time: "20:15", unread: 0, muted: false, pinned: false, read: true),
            Chat(id: Store.lenaId, originalTitle: "Pixel Perfect", kind: .channel, memberCount: 3912, colorIndex: 6, initials: "PP",
                 author: nil, preview: "Portfolio teardown #48: why your case study needs fewer screens and more decisions", time: "19:02", unread: 0, muted: true, pinned: false, read: false),
            Chat(id: "typo", originalTitle: "Typography Daily", kind: .channel, memberCount: 48210, colorIndex: 5, initials: "TD",
                 author: nil, preview: "Optical sizes explained: why the same font looks different at 12 and 48 pt", time: "17:44", unread: 0, muted: true, pinned: false, read: false),
            Chat(id: "ilya", originalTitle: "Ilya Kozlov", kind: .user, memberCount: nil, colorIndex: 3, initials: "IK",
                 author: nil, preview: "Sounds good, see you at 10 tomorrow", time: "Yesterday", unread: 0, muted: false, pinned: false, read: true),
            Chat(id: Store.mikeId, originalTitle: "Mike Ozornin's Stream", kind: .channel, memberCount: 312, colorIndex: 4, initials: "MO",
                 author: nil, preview: Store.mikePost, time: "Sat", unread: 0, muted: false, pinned: false, read: false, avatarImage: "mike-ozornin.jpg")
        ]
    }()

    func chat(_ id: String) -> Chat? {
        return self.chats.first(where: { $0.id == id })
    }

    func customName(_ id: String) -> String? {
        return self.customNames[id]
    }

    /// What this user sees as the chat's title: their private custom name, if any.
    func displayTitle(_ id: String) -> String {
        guard let chat = self.chat(id) else { return "" }
        return self.customNames[id] ?? chat.originalTitle
    }

    func setCustomName(_ id: String, _ name: String?) {
        let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines)
        // Empty, or exactly the original title (case-sensitive), means no custom name.
        if let trimmed, !trimmed.isEmpty, trimmed != self.chat(id)?.originalTitle {
            self.customNames[id] = trimmed
        } else {
            self.customNames.removeValue(forKey: id)
        }
        self.notify()
    }

    @discardableResult
    func observe(_ fn: @escaping () -> Void) -> UUID {
        let id = UUID()
        self.observers.append((id, fn))
        return id
    }

    func removeObserver(_ id: UUID) {
        self.observers.removeAll(where: { $0.id == id })
    }

    private func notify() {
        for o in self.observers { o.fn() }
    }

    static func formatCount(_ value: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.locale = Locale(identifier: "en_US")
        return f.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    /// "12,480 subscribers" / "1,204 members" (Conversation.StatusSubscribers_any / Conversation.StatusMembers_any).
    func statusText(_ chat: Chat) -> String {
        guard let count = chat.memberCount else { return "last seen recently" }
        switch chat.kind {
        case .channel: return "\(Store.formatCount(count)) subscribers"
        case .group: return "\(Store.formatCount(count)) members"
        case .user: return "last seen recently"
        }
    }
}
