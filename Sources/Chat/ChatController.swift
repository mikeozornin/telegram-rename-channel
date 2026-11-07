import UIKit
import Display
import GradientBackground

enum ChatViewer {
    case me
    case anya
}

/// A message in the fixed demo histories.
struct DemoMessage {
    enum Forward {
        case channel(String) // chat id of the forwarded-from channel
    }
    let author: String?          // nil: the viewer's own message (outgoing)
    let authorColor: UIColor
    let avatar: (Int, String)?
    let text: String
    let time: String
    let views: String?
    let forward: Forward?
}

/// Channel / group screen. Glass chrome (ChatController preferredGlassType .default): back circle, title capsule
/// (ChatTitleComponent.swift: 44 high, semibold 17 black, subtitle regular 12 black 50%, side inset 14, min width
/// 178) and the avatar (38 in a 44 container, ChatAvatarNavigationNode.swift:82-83). Bubbles: classic day theme
/// (incoming white, outgoing #e1ffc7, DefaultDayPresentationTheme.swift:588-684), text regular 17, insets 6/11,
/// corners 16 / 8 merged; time regular 11. Wallpaper: Telegram's GradientBackgroundNode with the classic colours.
final class ChatController: UIViewController {
    let chatId: String
    let viewer: ChatViewer
    private let wallpaper = GradientBackgroundNode(colors: [UIColor(rgb: 0xdbddbb), UIColor(rgb: 0x6ba587), UIColor(rgb: 0xd5d88d), UIColor(rgb: 0x88b884)], useSharedAnimationPhase: true)
    private let scroll = UIScrollView()
    private let header = GlassNavHeader()
    private let backButton = GlassButton.back()
    private let titlePill = ChatTitlePill()
    private let avatarButton: GlassButton
    private var bubbles: [MessageBubbleView] = []
    private lazy var datePill: ServicePill = {
        // The date header matches the chat-list time: a weekday or "Yesterday", else "Today".
        let time = self.chat.time
        let days = ["Mon": "Monday", "Tue": "Tuesday", "Wed": "Wednesday", "Thu": "Thursday", "Fri": "Friday", "Sat": "Saturday", "Sun": "Sunday"]
        return ServicePill(text: days[time] ?? (time == "Yesterday" ? "Yesterday" : "Today"))
    }()
    private let bottomPanel: UIView
    private var observer: UUID?

    init(chatId: String, viewer: ChatViewer = .me) {
        self.chatId = chatId
        self.viewer = viewer
        let chat = Store.shared.chat(chatId)!
        self.avatarButton = GlassButton()
        if chat.kind == .channel {
            self.bottomPanel = ChannelSubscriberPanel()
        } else {
            self.bottomPanel = ChatInputPanel()
        }
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    deinit {
        if let observer { Store.shared.removeObserver(observer) }
    }

    private var chat: Chat { return Store.shared.chat(self.chatId)! }

    private func messages() -> [DemoMessage] {
        let store = Store.shared
        let target = store.target
        if self.chatId == Store.designersId {
            let kate = UIColor(rgb: 0xe05c5c), anya = UIColor(rgb: 0x3e9ee0), alex = UIColor(rgb: 0x50a14f)
            let isAnya = self.viewer == .anya
            return [
                DemoMessage(author: "Kate", authorColor: kate, avatar: (0, "K"), text: "Morning! Who’s up for a crit session on Friday?", time: "21:31", views: nil, forward: nil),
                DemoMessage(author: isAnya ? "Alex" : nil, authorColor: alex, avatar: isAnya ? (3, "A") : nil, text: "I’m in. 4 pm works for me", time: "21:33", views: nil, forward: nil),
                DemoMessage(author: isAnya ? nil : "Anya", authorColor: anya, avatar: isAnya ? nil : (5, "A"), text: target.kind == .group ? "Does anyone track sleep with a ring? Mine says I rested 4 hours and I feel great 🦫" : "Habit trackers don’t fail. We just stop opening them. Three tricks that kept me going for a year: one habit at a time, track the streak, and rest days count as days 🦫", time: "21:39", views: nil, forward: .channel(Store.targetId)),
                DemoMessage(author: isAnya ? nil : "Anya", authorColor: anya, avatar: isAnya ? nil : (5, "A"), text: "👀 look what I found", time: "21:40", views: nil, forward: nil)
            ]
        }
        if self.chatId == Store.mikeId {
            return [DemoMessage(author: nil, authorColor: .clear, avatar: nil, text: Store.mikePost, time: "18:24", views: "287", forward: nil)]
        }
        if self.chatId != Store.targetId {
            // Chats outside the scenario show their last message only.
            let chat = self.chat
            return [DemoMessage(author: nil, authorColor: .clear, avatar: nil, text: chat.preview, time: chat.time.count <= 5 && chat.time.contains(":") ? chat.time : "18:00", views: chat.kind == .channel ? "1.9K" : nil, forward: nil)]
        }
        if self.chat.kind == .group {
            return [
                DemoMessage(author: "Lena", authorColor: UIColor(rgb: 0xd669ed), avatar: (6, "L"), text: "Morning, beavers! What’s everyone tracking this week?", time: "21:52", views: nil, forward: nil),
                DemoMessage(author: "Max", authorColor: UIColor(rgb: 0xe08a3e), avatar: (1, "M"), text: "Does anyone track sleep with a ring? Mine says I rested 4 hours and I feel great 🦫", time: "21:58", views: nil, forward: nil)
            ]
        }
        return [
            DemoMessage(author: nil, authorColor: .clear, avatar: nil, text: "New week, new experiment: no phone for the first hour after waking up. Who’s in? Report back on Friday ☀️", time: "09:12", views: "11K", forward: nil),
            DemoMessage(author: nil, authorColor: .clear, avatar: nil, text: "Habit trackers don’t fail. We just stop opening them.\n\nThree tricks that kept me going for a year:\n1. One habit at a time.\n2. Track the streak, not the score.\n3. Rest days count as days 🦫", time: "21:58", views: "8.4K", forward: nil)
        ]
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = UIColor(rgb: 0xa8c49a)
        self.view.addSubview(self.wallpaper.view)
        self.scroll.alwaysBounceVertical = true
        self.scroll.contentInsetAdjustmentBehavior = .never
        self.view.addSubview(self.scroll)
        self.scroll.addSubview(self.datePill)

        let isChannelHistory = self.chat.kind == .channel && self.chatId != Store.designersId
        let messages = self.messages()
        for (i, message) in messages.enumerated() {
            let bubble = MessageBubbleView(message: message, isChannelPost: isChannelHistory)
            if !isChannelHistory {
                if i > 0, messages[i - 1].author == message.author { bubble.mergedWithPrevious = true }
                if i + 1 < messages.count, messages[i + 1].author == message.author { bubble.mergedWithNext = true }
            }
            bubble.onForwardTap = { [weak self] id in self?.openForwardSource(id) }
            self.bubbles.append(bubble)
            self.scroll.addSubview(bubble)
        }

        self.view.addSubview(self.bottomPanel)

        let chat = self.chat
        let avatar = AvatarView(chat: chat)
        self.avatarButton.content.addSubview(avatar)
        self.avatarButton.accessibilityLabel = "Profile"
        avatar.tag = 501
        self.avatarButton.onTap = { [weak self] in self?.openInfo() }
        self.backButton.onTap = { App.shared.pop() }
        self.titlePill.onTap = { [weak self] in self?.openInfo() }
        self.header.leftButton = self.backButton
        self.header.rightButton = self.avatarButton
        self.header.titleView = self.titlePill
        self.view.addSubview(self.header)

        self.updateTitle()
        self.observer = Store.shared.observe { [weak self] in self?.updateTitle() }
    }

    private func updateTitle() {
        let store = Store.shared
        let chat = self.chat
        self.titlePill.set(title: store.displayTitle(self.chatId), subtitle: store.statusText(chat))
        for b in self.bubbles { b.refreshForward(viewer: self.viewer) }
        self.view.setNeedsLayout()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let size = self.view.bounds.size
        let top = self.view.safeAreaInsets.top
        let bottom = self.view.safeAreaInsets.bottom
        self.wallpaper.frame = self.view.bounds
        self.wallpaper.updateLayout(size: size, transition: .immediate, extendAnimation: false, backwards: false, completion: {})
        self.scroll.frame = self.view.bounds
        self.header.frame = CGRect(x: 0.0, y: 0.0, width: size.width, height: top + GlassNavHeader.barHeight)
        self.header.topInset = top
        if let avatar = self.avatarButton.content.viewWithTag(501) {
            avatar.frame = CGRect(x: 3.0, y: 3.0, width: 38.0, height: 38.0)
        }

        let panelHeight: CGFloat = 40.0
        let panelY = size.height - max(bottom - 6.0, 8.0) - panelHeight
        self.bottomPanel.frame = CGRect(x: 8.0, y: panelY, width: size.width - 16.0, height: panelHeight)

        // Lay the history out from the bottom, as a chat list does.
        var heights: [CGFloat] = []
        for b in self.bubbles {
            heights.append(b.layout(width: size.width))
        }
        let spacing: CGFloat = 2.0 + 1.0 / 3.0 + 4.0
        var total = 34.0 + heights.reduce(0.0, +) + spacing * CGFloat(max(0, heights.count - 1))
        total += 8.0
        let contentBottom = panelY - 10.0
        var y = max(top + GlassNavHeader.barHeight + 8.0, contentBottom - total)
        let pillSize = self.datePill.sizeThatFits(.zero)
        self.datePill.frame = CGRect(x: floor((size.width - pillSize.width) / 2.0), y: y + 6.0, width: pillSize.width, height: pillSize.height)
        y += 34.0
        for (i, b) in self.bubbles.enumerated() {
            b.frame = CGRect(x: 0.0, y: y, width: size.width, height: heights[i])
            y += heights[i] + (b.mergedWithNext ? 2.0 : spacing)
        }
        self.scroll.contentSize = CGSize(width: size.width, height: max(y + (size.height - contentBottom), size.height))
    }

    // MARK: - Actions

    func openInfo() {
        guard self.chatId == Store.targetId else { return }
        App.shared.push(PeerInfoController(chatId: self.chatId))
    }

    func openForwardSource(_ id: String) {
        App.shared.push(ChatController(chatId: id))
    }

    var titleCenter: CGPoint { return self.titlePill.convert(CGPoint(x: self.titlePill.bounds.midX, y: self.titlePill.bounds.midY), to: nil) }
    var backCenter: CGPoint { return self.backButton.screenCenter }
    var forwardHeaderCenter: CGPoint? {
        for b in self.bubbles {
            if let p = b.forwardHeaderCenter { return p }
        }
        return nil
    }
}

// MARK: - Title capsule

final class ChatTitlePill: GlassPanelView {
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    var onTap: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.isInteractiveGlass = true
        self.titleLabel.font = Font.semibold(17.0)
        self.titleLabel.textColor = UIColor(rgb: 0x000000)
        self.titleLabel.textAlignment = .center
        self.titleLabel.lineBreakMode = .byTruncatingTail
        self.subtitleLabel.font = Font.regular(12.0)
        self.subtitleLabel.textColor = UIColor(rgb: 0x000000, alpha: 0.5)
        self.subtitleLabel.textAlignment = .center
        self.content.addSubview(self.titleLabel)
        self.content.addSubview(self.subtitleLabel)
        self.isAccessibilityElement = true
        self.accessibilityTraits = .button
        self.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tapped)))
    }

    required init?(coder: NSCoder) { fatalError() }

    func set(title: String, subtitle: String) {
        self.titleLabel.text = title
        self.titleLabel.applyEmojiFallback()
        self.subtitleLabel.text = subtitle
        self.accessibilityLabel = "\(title), \(subtitle)"
        self.superview?.setNeedsLayout()
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        let t = ceil(self.titleLabel.sizeThatFits(CGSize(width: 1000.0, height: 30.0)).width)
        let s = ceil(self.subtitleLabel.sizeThatFits(CGSize(width: 1000.0, height: 30.0)).width)
        let textWidth = max(min(150.0, size.width - 28.0), max(t, s))
        return CGSize(width: min(size.width, textWidth + 28.0), height: 44.0)
    }

    override func layoutContent(size: CGSize) {
        self.titleLabel.frame = CGRect(x: 14.0, y: 3.0, width: size.width - 28.0, height: 21.0)
        self.subtitleLabel.frame = CGRect(x: 14.0, y: 23.0, width: size.width - 28.0, height: 16.0)
    }

    @objc private func tapped() { self.onTap?() }
}

// MARK: - Date pill

final class ServicePill: UIView {
    private let label = UILabel()

    init(text: String) {
        super.init(frame: .zero)
        // ChatMessageDateHeader.swift: 22 high, padding, corner 11, medium 13; classic service colours.
        self.backgroundColor = Theme.Bubble.service
        self.layer.cornerRadius = 11.0
        self.label.text = text
        self.label.font = Font.medium(13.0)
        self.label.textColor = .white
        self.addSubview(self.label)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        let w = ceil(self.label.sizeThatFits(CGSize(width: 300.0, height: 30.0)).width)
        return CGSize(width: w + 16.0, height: 22.0)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        self.label.frame = self.bounds.insetBy(dx: 8.0, dy: 0.0)
    }
}

// MARK: - Bottom panels

/// ChatChannelSubscriberInputPanelNode in glass mode: a "Mute" capsule (40 high, corner 20, min width 165, medium 17
/// black, GlassControlGroup.swift:153/:241, GlassControlPanel.swift:349) and the search circle on the right.
final class ChannelSubscriberPanel: UIView {
    private let muteButton = GlassButton(title: "Mute")
    private let searchButton = GlassButton(iconName: "Chat List/SearchIcon")

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.searchButton.accessibilityLabel = "Search"
        self.addSubview(self.muteButton)
        self.addSubview(self.searchButton)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        let size = self.bounds.size
        let w = max(165.0, self.muteButton.preferredWidth(height: 40.0))
        self.muteButton.frame = CGRect(x: floor((size.width - w) / 2.0), y: 0.0, width: w, height: 40.0)
        self.searchButton.frame = CGRect(x: size.width - 40.0, y: 0.0, width: 40.0, height: 40.0)
    }
}

/// The group's text input panel: attach circle, "Message" capsule, microphone circle (glass).
final class ChatInputPanel: UIView {
    private let attach = GlassButton(iconName: "Chat/Input/Text/IconAttachment")
    private let field = GlassPanelView()
    private let placeholder = UILabel()
    private let mic = GlassButton(iconName: "Chat/Input/Text/IconMicrophone")

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.attach.accessibilityLabel = "Attach"
        self.mic.accessibilityLabel = "Voice message"
        self.field.cornerRadius = 20.0
        self.placeholder.text = "Message"
        self.placeholder.font = Font.regular(17.0)
        self.placeholder.textColor = UIColor(rgb: 0x000000, alpha: 0.4)
        self.field.content.addSubview(self.placeholder)
        self.addSubview(self.attach)
        self.addSubview(self.field)
        self.addSubview(self.mic)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        let size = self.bounds.size
        self.attach.frame = CGRect(x: 0.0, y: 0.0, width: 40.0, height: 40.0)
        self.mic.frame = CGRect(x: size.width - 40.0, y: 0.0, width: 40.0, height: 40.0)
        self.field.frame = CGRect(x: 48.0, y: 0.0, width: size.width - 96.0, height: 40.0)
        self.placeholder.frame = CGRect(x: 14.0, y: 0.0, width: self.field.bounds.width - 28.0, height: 40.0)
    }
}
