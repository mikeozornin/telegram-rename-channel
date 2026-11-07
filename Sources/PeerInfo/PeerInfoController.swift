import UIKit
import Display

/// Channel / group profile. Header metrics from TelegramUI/Components/PeerInfo/PeerInfoScreen/Sources/
/// PeerInfoHeaderNode.swift (avatar 100 at statusBar + 22 :647/:749, title medium 28 at avatar.maxY + 9 :1310/:1800,
/// subtitle regular 17 secondary :1380), PeerInfoHeaderButtonNode.swift (58 high, corner 16, icon 40 at y 1,
/// label regular 11 lowercased at h - labelH - 9, spacing 8, side 16), PeerInfoScreenLabeledValueItem.swift
/// (label regular 14 above value regular 17, padding 15, gap 3), page background blocks 0xefeff4 (PeerInfoScreen:1368).
final class PeerInfoController: UIViewController {
    let chatId: String
    private let scroll = UIScrollView()
    private let header = GlassNavHeader()
    private let backButton = GlassButton.back()
    private let editButton = GlassButton(title: "Edit")
    private var avatar: AvatarView!
    private let titleLabel = UILabel()
    private let originalLabel = UILabel()
    private let statusLabel = UILabel()
    private var buttons: [PeerInfoActionButton] = []
    private let infoBlock = UIView()
    private var infoRows: [(UILabel, UILabel)] = []
    private var observer: UUID?

    init(chatId: String) {
        self.chatId = chatId
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    deinit {
        if let observer { Store.shared.removeObserver(observer) }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        let chat = Store.shared.chat(self.chatId)!
        self.view.backgroundColor = Theme.List.blocksBackground
        self.scroll.alwaysBounceVertical = true
        self.scroll.contentInsetAdjustmentBehavior = .never
        self.view.addSubview(self.scroll)

        self.avatar = AvatarView(chat: chat)
        self.scroll.addSubview(self.avatar)

        self.titleLabel.font = Font.medium(28.0)
        self.titleLabel.textColor = Theme.List.primaryText
        self.titleLabel.textAlignment = .center
        self.titleLabel.lineBreakMode = .byTruncatingTail
        self.titleLabel.numberOfLines = 2
        self.scroll.addSubview(self.titleLabel)

        self.originalLabel.font = Font.regular(17.0)
        self.originalLabel.textColor = Theme.List.secondaryText
        self.originalLabel.textAlignment = .center
        self.scroll.addSubview(self.originalLabel)

        self.statusLabel.font = Font.regular(17.0)
        self.statusLabel.textColor = Theme.List.secondaryText
        self.statusLabel.textAlignment = .center
        self.statusLabel.text = Store.shared.statusText(chat)
        self.scroll.addSubview(self.statusLabel)

        // Header buttons for a subscriber / member: Mute, Search, Leave, More (PeerInfoData.swift:2770-2800).
        let specs: [(String, String)] = [("Mute", "Peer Info/ButtonMute"), ("Search", "Peer Info/ButtonSearch"), ("Leave", "Peer Info/ButtonLeave"), ("More", "Peer Info/ButtonMore")]
        for (title, iconName) in specs {
            let b = PeerInfoActionButton(title: title, iconName: iconName)
            self.buttons.append(b)
            self.scroll.addSubview(b)
        }
        self.buttons[3].onTap = { [weak self] in self?.openMoreMenu() }

        self.infoBlock.backgroundColor = Theme.List.itemBlocksBackground
        self.infoBlock.layer.cornerRadius = 26.0
        self.infoBlock.layer.cornerCurve = .continuous
        self.scroll.addSubview(self.infoBlock)
        let link = chat.kind == .group ? "https://t.me/beaversprodchat" : "https://t.me/beaversprod"
        let description = chat.kind == .group ? "Chat for the Beavers & Productivity channel. Share your setups, ask questions, be kind." : "Personal productivity without the fanaticism: habits, trackers, rest. Sometimes beavers."
        // Order as PeerInfoProfileItems.swift: share link (id 1) then description (id 3).
        for (label, value, isLink) in [("share link", link, true), ("description", description, false)] {
            let l = UILabel()
            l.font = Font.regular(14.0)
            l.textColor = Theme.List.primaryText
            l.text = label
            let v = UILabel()
            v.font = Font.regular(17.0)
            v.numberOfLines = 0
            v.textColor = isLink ? Theme.accent : Theme.List.primaryText
            v.text = value
            self.infoBlock.addSubview(l)
            self.infoBlock.addSubview(v)
            self.infoRows.append((l, v))
        }

        self.backButton.accessibilityLabel = "Back"
        self.backButton.onTap = { App.shared.pop() }
        self.editButton.onTap = { [weak self] in self?.openRename() }
        self.header.leftButton = self.backButton
        self.header.rightButton = self.editButton
        self.header.showsEdgeEffect = true
        self.header.edgeColor = Theme.List.blocksBackground
        self.view.addSubview(self.header)

        self.updateTitle()
        self.observer = Store.shared.observe { [weak self] in self?.updateTitle() }
    }

    private func updateTitle() {
        let store = Store.shared
        let chat = store.chat(self.chatId)!
        self.titleLabel.text = store.displayTitle(self.chatId)
        self.titleLabel.applyEmojiFallback()
        if store.customName(self.chatId) != nil {
            self.originalLabel.text = chat.originalTitle
            self.originalLabel.isHidden = false
        } else {
            self.originalLabel.isHidden = true
        }
        self.view.setNeedsLayout()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let width = self.view.bounds.width
        let top = self.view.safeAreaInsets.top
        self.scroll.frame = self.view.bounds
        self.header.frame = CGRect(x: 0.0, y: 0.0, width: width, height: top + GlassNavHeader.barHeight)
        self.header.topInset = top

        self.avatar.frame = CGRect(x: floor((width - 100.0) / 2.0), y: top + 22.0, width: 100.0, height: 100.0)
        let titleSize = self.titleLabel.sizeThatFits(CGSize(width: width - 32.0, height: 200.0))
        self.titleLabel.frame = CGRect(x: 16.0, y: self.avatar.frame.maxY + 9.0, width: width - 32.0, height: ceil(titleSize.height))
        var y = self.titleLabel.frame.maxY + 1.0
        if !self.originalLabel.isHidden {
            self.originalLabel.frame = CGRect(x: 16.0, y: y, width: width - 32.0, height: 22.0)
            y = self.originalLabel.frame.maxY
        }
        self.statusLabel.frame = CGRect(x: 16.0, y: y, width: width - 32.0, height: 22.0)
        y = self.statusLabel.frame.maxY + 20.0

        let spacing: CGFloat = 8.0
        let side: CGFloat = 16.0
        let buttonWidth = (width - side * 2.0 - spacing * CGFloat(self.buttons.count - 1)) / CGFloat(self.buttons.count)
        for (i, b) in self.buttons.enumerated() {
            b.frame = CGRect(x: side + CGFloat(i) * (buttonWidth + spacing), y: y, width: buttonWidth, height: 58.0)
        }
        y += 58.0 + 16.0 + 8.0

        var rowY: CGFloat = 0.0
        let innerWidth = width - side * 2.0 - 32.0
        for (index, (l, v)) in self.infoRows.enumerated() {
            let ls = l.sizeThatFits(CGSize(width: innerWidth, height: 100.0))
            let vs = v.sizeThatFits(CGSize(width: innerWidth, height: 400.0))
            l.frame = CGRect(x: 16.0, y: rowY + 15.0, width: innerWidth, height: ceil(ls.height))
            v.frame = CGRect(x: 16.0, y: l.frame.maxY + 3.0, width: innerWidth, height: ceil(vs.height))
            rowY = v.frame.maxY + 15.0
            if index == 0 {
                let sep = self.infoBlock.viewWithTag(77) ?? {
                    let s = UIView()
                    s.tag = 77
                    s.backgroundColor = Theme.List.separator
                    self.infoBlock.addSubview(s)
                    return s
                }()
                sep.frame = CGRect(x: 16.0, y: rowY - UIScreenPixel, width: width - side * 2.0 - 32.0, height: UIScreenPixel)
            }
        }
        self.infoBlock.frame = CGRect(x: side, y: y, width: width - side * 2.0, height: rowY)
        self.scroll.contentSize = CGSize(width: width, height: self.infoBlock.frame.maxY + 40.0)
    }

    // MARK: - Actions

    func openRename() {
        RenameController.present(chatId: self.chatId, animated: true)
    }

    func openMoreMenu() {
        let chat = Store.shared.chat(self.chatId)!
        let renameTitle = Store.shared.customName(self.chatId) == nil ? "Rename for me" : "Edit custom name"
        var items: [ContextMenuItem] = [
            ContextMenuItem(title: renameTitle, iconName: "Chat/Context Menu/Edit", action: { [weak self] in
                guard let self else { return }
                after(0.25) { self.openRename() }
            })
        ]
        if chat.kind == .channel {
            items.append(ContextMenuItem(title: "Send a Gift", iconName: "Chat/Context Menu/Gift"))
            items.append(ContextMenuItem(title: "Boost Channel", iconName: "Chat/Context Menu/Boost"))
        }
        items.append(ContextMenuItem(title: "Clear Messages", iconName: "Chat/Context Menu/ClearMessages"))
        items.append(ContextMenuItem(title: "Report", iconName: "Chat/Context Menu/Report"))
        let source = self.buttons[3]
        ContextMenuController.present(items: items, source: .button(source))
    }

    var editButtonCenter: CGPoint { return self.editButton.convert(CGPoint(x: self.editButton.bounds.midX, y: self.editButton.bounds.midY), to: nil) }
    var backButtonCenter: CGPoint { return self.backButton.convert(CGPoint(x: self.backButton.bounds.midX, y: self.backButton.bounds.midY), to: nil) }
    var moreButtonCenter: CGPoint { return self.buttons[3].convert(CGPoint(x: self.buttons[3].bounds.midX, y: self.buttons[3].bounds.midY), to: nil) }
}

/// A profile header action button: white rounded rect, accent icon and lowercased label (PeerInfoHeaderButtonNode).
final class PeerInfoActionButton: UIView {
    private let iconView = UIImageView()
    private let label = UILabel()
    private let highlightView = UIView()
    var onTap: (() -> Void)?

    init(title: String, iconName: String) {
        super.init(frame: .zero)
        self.backgroundColor = Theme.List.itemBlocksBackground
        self.layer.cornerRadius = 16.0
        self.layer.cornerCurve = .continuous
        self.clipsToBounds = true
        self.highlightView.backgroundColor = Theme.List.highlight
        self.highlightView.alpha = 0.0
        self.addSubview(self.highlightView)
        self.iconView.image = icon(iconName, Theme.accent)
        self.iconView.contentMode = .center
        self.addSubview(self.iconView)
        self.label.text = title.lowercased()
        self.label.font = Font.regular(11.0)
        self.label.textColor = Theme.accent
        self.label.textAlignment = .center
        self.addSubview(self.label)
        self.isAccessibilityElement = true
        self.accessibilityLabel = title
        self.accessibilityTraits = .button
        self.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tapped)))
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        let size = self.bounds.size
        self.highlightView.frame = self.bounds
        self.iconView.frame = CGRect(x: floor((size.width - 40.0) / 2.0), y: 1.0, width: 40.0, height: 40.0)
        let ls = self.label.sizeThatFits(CGSize(width: size.width, height: 20.0))
        self.label.frame = CGRect(x: 0.0, y: size.height - ceil(ls.height) - 9.0, width: size.width, height: ceil(ls.height))
    }

    @objc private func tapped() {
        UIView.animate(withDuration: 0.05, animations: { self.highlightView.alpha = 1.0 }, completion: { _ in
            UIView.animate(withDuration: 0.3) { self.highlightView.alpha = 0.0 }
        })
        self.onTap?()
    }
}
