import UIKit
import Display

/// The Chats tab. Header (ChatListHeaderComponent / ChatListNavigationBar): a 44 pt row at statusBar + 10 with the
/// "Edit" glass capsule (medium 17) on the left, "Chats" (semibold 17) centred and the accent compose circle on the
/// right; below it the search field (44 high, 16 from the sides, fill black 6%, corner 22, "Search" regular 17
/// #8e8e93 with the 24 pt loupe, centred at rest; SearchBarPlaceholderNode / NavigationBarSearchContentNode).
/// Header height statusBar + 121 (ChatListNavigationBar.swift:952-1027).
final class ChatListController: UIViewController, UIScrollViewDelegate {
    private let scroll = UIScrollView()
    private let header = GlassNavHeader()
    private let editButton = GlassButton(title: "Edit")
    private let composeButton = GlassButton(iconName: "Chat List/ComposeIcon", iconColor: .white, accent: true)
    let searchField = SearchFieldView()
    let tabBar = TabBarView()
    private(set) var rows: [ChatListRowView] = []
    private var observer: UUID?
    private(set) var search: ChatListSearchView?

    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = Theme.ChatList.background
        self.scroll.alwaysBounceVertical = true
        self.scroll.contentInsetAdjustmentBehavior = .never
        self.scroll.delegate = self
        self.view.addSubview(self.scroll)

        for (i, chat) in Store.shared.chats.enumerated() {
            let row = ChatListRowView(chat: chat)
            row.showsSeparator = i != Store.shared.chats.count - 1
            row.onTap = { [weak self] in self?.openChat(chat.id) }
            row.onLongPress = { [weak self] in self?.openContextMenu(chatId: chat.id) }
            self.rows.append(row)
            self.scroll.addSubview(row)
        }
        self.scroll.addSubview(self.searchField)
        self.searchField.onTap = { [weak self] in self?.activateSearch(animated: true, query: nil) }

        self.header.title = "Chats"
        self.header.leftButton = self.editButton
        self.header.rightButton = self.composeButton
        self.composeButton.accessibilityLabel = "Compose"
        self.header.showsEdgeEffect = true
        self.header.edgeColor = Theme.ChatList.background
        self.view.addSubview(self.header)
        self.view.addSubview(self.tabBar)

        self.observer = Store.shared.observe { [weak self] in self?.refreshTitles() }
    }

    func refreshTitles() {
        for row in self.rows {
            row.update(title: Store.shared.displayTitle(row.chatId))
        }
        self.search?.refresh()
    }

    var statusBarHeight: CGFloat { return self.view.window?.safeAreaInsets.top ?? self.view.safeAreaInsets.top }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let width = self.view.bounds.width
        let top = self.view.safeAreaInsets.top
        let headerHeight = top + 121.0
        self.scroll.frame = self.view.bounds
        // Row 44 at statusBar + 10 (ChatListNavigationBar.swift:682).
        self.header.buttonsY = top + 10.0
        self.header.frame = CGRect(x: 0.0, y: 0.0, width: width, height: top + 56.0)
        // Search field: node at statusBar + 3 + 44 + 9, field 8 pt inside it (CLNB:1013, SBN:134-137).
        self.searchField.frame = CGRect(x: 16.0, y: top + 3.0 + 44.0 + 9.0 + 8.0, width: width - 32.0, height: 44.0)
        var y = headerHeight
        for row in self.rows {
            row.frame = CGRect(x: 0.0, y: y, width: width, height: ChatListRowView.height)
            y += ChatListRowView.height
        }
        let bottomInset = self.view.safeAreaInsets.bottom
        self.scroll.contentSize = CGSize(width: width, height: max(y + TabBarView.barHeight + TabBarView.bottomInset + 20.0, self.view.bounds.height + 1.0))
        _ = bottomInset
        let tabY = self.view.bounds.height - TabBarView.bottomInset - TabBarView.barHeight
        self.tabBar.frame = CGRect(x: TabBarView.sideInset, y: tabY, width: width - TabBarView.sideInset * 2.0, height: TabBarView.barHeight)
        self.search?.frame = self.view.bounds
    }

    func row(_ chatId: String) -> ChatListRowView? {
        return self.rows.first(where: { $0.chatId == chatId })
    }

    // MARK: - Actions

    func openChat(_ chatId: String) {
        App.shared.push(ChatController(chatId: chatId))
    }

    func openContextMenu(chatId: String) {
        guard let row = self.row(chatId), let chat = Store.shared.chat(chatId) else { return }
        let hasCustom = Store.shared.customName(chatId) != nil
        var items: [ContextMenuItem] = []
        // ChatContextMenus.swift order for a channel / group: Mark as Read, Pin, (new) Rename, Mute, Leave.
        if chat.unread > 0 {
            items.append(ContextMenuItem(title: "Mark as Read", iconName: "Chat/Context Menu/MarkAsRead"))
        }
        items.append(ContextMenuItem(title: "Pin", iconName: "Chat/Context Menu/Pin"))
        if chat.kind == .channel || chat.kind == .group {
            items.append(ContextMenuItem(title: hasCustom ? "Edit custom name" : "Rename for me", iconName: "Chat/Context Menu/Edit", action: {
                after(0.3) { RenameController.present(chatId: chatId, animated: true) }
            }))
        }
        items.append(ContextMenuItem(title: chat.muted ? "Unmute" : "Mute", iconName: chat.muted ? "Chat/Context Menu/Unmute" : "Chat/Context Menu/Muted"))
        switch chat.kind {
        case .channel:
            items.append(ContextMenuItem(title: "Leave Channel", iconName: "Chat/Context Menu/Logout", destructive: true))
        case .group:
            items.append(ContextMenuItem(title: "Leave Group", iconName: "Chat/Context Menu/Logout", destructive: true))
        case .user:
            items.append(ContextMenuItem(title: "Delete", iconName: "Chat/Context Menu/Delete", destructive: true))
        }
        ContextMenuController.present(items: items, source: .chatRow(row))
    }

    func activateSearch(animated: Bool, query: String?) {
        guard self.search == nil else { return }
        let search = ChatListSearchView(host: self)
        self.search = search
        search.frame = self.view.bounds
        self.view.addSubview(search)
        search.activate(animated: animated, query: query)
    }

    func searchDidDeactivate() {
        self.search?.removeFromSuperview()
        self.search = nil
    }

    func setChromeHidden(_ hidden: Bool, animated: Bool) {
        let changes = {
            let dy: CGFloat = hidden ? -60.0 : 0.0
            self.header.alpha = hidden ? 0.0 : 1.0
            self.header.transform = CGAffineTransform(translationX: 0.0, y: dy)
            self.scroll.alpha = hidden ? 0.0 : 1.0
            self.tabBar.alpha = hidden ? 0.0 : 1.0
        }
        if animated {
            UIView.animate(withDuration: 0.3, delay: 0.0, options: [.curveEaseInOut], animations: changes)
        } else {
            changes()
        }
    }

    var editButtonCenter: CGPoint { return self.editButton.screenCenter }
}

/// The chat list's search field at rest: flat fill, centred loupe + "Search" (glass only while active).
final class SearchFieldView: UIView {
    private let loupe = UIImageView()
    private let label = UILabel()
    var onTap: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.backgroundColor = Theme.ChatList.searchFill
        self.layer.cornerRadius = 22.0
        self.loupe.image = icon("Components/Search Bar/Loupe", Theme.ChatList.searchPlaceholder)
        self.addSubview(self.loupe)
        self.label.text = "Search"
        self.label.font = Font.regular(17.0)
        self.label.textColor = Theme.ChatList.searchPlaceholder
        self.addSubview(self.label)
        self.isAccessibilityElement = true
        self.accessibilityLabel = "Search"
        self.accessibilityTraits = .searchField
        self.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tapped)))
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        let ls = self.label.sizeThatFits(CGSize(width: 200.0, height: 30.0))
        let iconSize = self.loupe.image?.size ?? CGSize(width: 24.0, height: 24.0)
        let total = iconSize.width + 2.0 + ceil(ls.width)
        let x = floor((self.bounds.width - total) / 2.0)
        self.loupe.frame = CGRect(x: x, y: 10.0, width: iconSize.width, height: iconSize.height)
        self.label.frame = CGRect(x: self.loupe.frame.maxX + 2.0, y: floor((self.bounds.height - ceil(ls.height)) / 2.0), width: ceil(ls.width), height: ceil(ls.height))
    }

    @objc private func tapped() {
        self.onTap?()
    }

    var screenCenter: CGPoint { return self.convert(CGPoint(x: self.bounds.midX, y: self.bounds.midY), to: nil) }
}
