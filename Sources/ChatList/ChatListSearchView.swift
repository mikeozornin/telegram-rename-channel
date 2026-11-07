import UIKit
import Display
import GlassBackgroundComponent

/// Active chat-list search. Field: glass .panel capsule, 44 high, narrowed by 44 + 8 for the glass close circle with
/// a drawn 2 pt X (SearchBarPlaceholderNode.swift:309-395). Results: section header "CHATS AND CONTACTS" (regular 13,
/// uppercased, 28 high; ChatListSearchItemHeader / ListSectionHeaderNode), peer rows as ContactsPeerItem (avatar 40
/// at x 15, title medium 17 at x 65, second line regular 13, row 6 + title + status + 6). Filter tabs: a 40 pt glass
/// capsule at the bottom, 12 pt above the keyboard (ChatListSearchContainerNode.swift:813-830; medium 15).
/// Empty: "No Results" semibold 17 + body regular 15 in the free-text colour (ChatListSearchListPaneNode.swift:1870).
final class ChatListSearchView: UIView, UITextFieldDelegate {
    private weak var host: ChatListController?
    private let background = UIView()
    private let fieldGlass = GlassPanelView()
    private let loupe = UIImageView()
    let textField = UITextField()
    private let clearButton = UIButton(type: .custom)
    private let closeButton = GlassButton()
    private let results = UIScrollView()
    private let sectionHeader = UILabel()
    private var rows: [SearchResultRow] = []
    private let emptyTitle = UILabel()
    private let emptyText = UILabel()
    private let filters = SearchFiltersView()
    private var keyboardHeight: CGFloat = 0.0

    init(host: ChatListController) {
        self.host = host
        super.init(frame: .zero)
        self.background.backgroundColor = Theme.List.plainBackground
        self.addSubview(self.background)
        self.addSubview(self.results)
        self.results.alwaysBounceVertical = true
        self.results.keyboardDismissMode = .onDrag
        self.results.contentInsetAdjustmentBehavior = .never

        self.sectionHeader.text = "Chats and Contacts".uppercased()
        self.sectionHeader.font = Font.regular(13.0)
        self.sectionHeader.textColor = Theme.List.freeText
        self.results.addSubview(self.sectionHeader)

        self.emptyTitle.text = "No Results"
        self.emptyTitle.font = Font.semibold(17.0)
        self.emptyTitle.textColor = Theme.List.freeText
        self.emptyTitle.textAlignment = .center
        self.emptyText.numberOfLines = 0
        self.emptyText.textAlignment = .center
        self.addSubview(self.emptyTitle)
        self.addSubview(self.emptyText)

        self.fieldGlass.cornerRadius = 22.0
        self.fieldGlass.isInteractiveGlass = true
        self.addSubview(self.fieldGlass)
        self.loupe.image = icon("Components/Search Bar/Loupe", Theme.ChatList.searchPlaceholder)
        self.fieldGlass.content.addSubview(self.loupe)
        self.textField.font = Font.regular(17.0)
        self.textField.textColor = .black
        self.textField.tintColor = Theme.accent
        self.textField.attributedPlaceholder = NSAttributedString(string: "Search", attributes: [.font: Font.regular(17.0), .foregroundColor: Theme.ChatList.searchPlaceholder])
        self.textField.returnKeyType = .search
        self.textField.autocorrectionType = .no
        self.textField.autocapitalizationType = .none
        self.textField.delegate = self
        self.textField.accessibilityLabel = "Search"
        self.textField.addTarget(self, action: #selector(self.queryChanged), for: .editingChanged)
        self.fieldGlass.content.addSubview(self.textField)
        self.clearButton.setImage(icon("Components/Search Bar/Clear", Theme.ChatList.searchPlaceholder), for: .normal)
        self.clearButton.accessibilityLabel = "Clear"
        self.clearButton.addTarget(self, action: #selector(self.clearTapped), for: .touchUpInside)
        self.fieldGlass.content.addSubview(self.clearButton)

        self.closeButton.setIcon(generateImage(CGSize(width: 40.0, height: 40.0), rotatedContext: { size, context in
            context.clear(CGRect(origin: .zero, size: size))
            context.setLineWidth(2.0)
            context.setLineCap(.round)
            context.setStrokeColor(UIColor.black.cgColor)
            context.move(to: CGPoint(x: 12.0, y: 12.0)); context.addLine(to: CGPoint(x: size.width - 12.0, y: size.height - 12.0))
            context.move(to: CGPoint(x: size.width - 12.0, y: 12.0)); context.addLine(to: CGPoint(x: 12.0, y: size.height - 12.0))
            context.strokePath()
        }))
        self.closeButton.accessibilityLabel = "Close search"
        self.closeButton.onTap = { [weak self] in self?.deactivate() }
        self.addSubview(self.closeButton)
        self.addSubview(self.filters)

        NotificationCenter.default.addObserver(self, selector: #selector(self.keyboardChanged(_:)), name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
        self.reload()
    }

    required init?(coder: NSCoder) { fatalError() }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    var query: String { return self.textField.text ?? "" }

    func activate(animated: Bool, query: String?) {
        if let query {
            self.textField.text = query
        }
        self.reload()
        self.layoutIfNeeded()
        self.host?.setChromeHidden(true, animated: animated)
        if animated {
            let target = self.fieldGlass.frame
            if let host = self.host {
                let from = host.searchField.convert(host.searchField.bounds, to: self)
                self.fieldGlass.frame = from
            }
            self.background.alpha = 0.0
            self.results.alpha = 0.0
            self.closeButton.alpha = 0.0
            self.filters.alpha = 0.0
            UIView.animate(withDuration: 0.35, delay: 0.0, usingSpringWithDamping: 0.9, initialSpringVelocity: 0.0, options: []) {
                self.fieldGlass.frame = target
                self.fieldGlass.layoutIfNeeded()
                self.background.alpha = 1.0
                self.results.alpha = 1.0
                self.closeButton.alpha = 1.0
                self.filters.alpha = 1.0
            }
        }
        self.textField.becomeFirstResponder()
    }

    func deactivate() {
        self.textField.resignFirstResponder()
        self.host?.setChromeHidden(false, animated: true)
        UIView.animate(withDuration: 0.25, animations: {
            self.alpha = 0.0
        }, completion: { _ in
            self.host?.searchDidDeactivate()
        })
    }

    func refresh() {
        self.reload()
    }

    private func reload() {
        let store = Store.shared
        let tokens = SearchMatcher.tokens(self.query)
        let matches = tokens.isEmpty ? [] : store.chats.filter { chat in
            var fields = [store.displayTitle(chat.id), chat.originalTitle]
            if chat.id == Store.targetId { fields.append("beaversprod") }
            return SearchMatcher.matches(tokens: tokens, fields: fields)
        }
        for r in self.rows { r.removeFromSuperview() }
        self.rows = matches.map { chat in
            let row = SearchResultRow(chat: chat, tokens: tokens)
            row.onTap = { [weak self] in self?.open(chat.id) }
            return row
        }
        for r in self.rows { self.results.addSubview(r) }
        let hasQuery = !tokens.isEmpty
        self.sectionHeader.isHidden = self.rows.isEmpty
        let isEmpty = hasQuery && self.rows.isEmpty
        self.emptyTitle.isHidden = !isEmpty
        self.emptyText.isHidden = !isEmpty
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineSpacing = 0.2
        let trimmed = self.query.trimmingCharacters(in: .whitespacesAndNewlines)
        self.emptyText.attributedText = NSAttributedString(string: "There were no results for \"\(trimmed)\".\nTry a new search.", attributes: [.font: Font.regular(15.0), .foregroundColor: Theme.List.freeText, .paragraphStyle: paragraph])
        self.clearButton.isHidden = self.query.isEmpty
        self.setNeedsLayout()
    }

    private func open(_ chatId: String) {
        self.textField.resignFirstResponder()
        App.shared.push(ChatController(chatId: chatId))
    }

    @objc private func queryChanged() {
        self.reload()
    }

    @objc private func clearTapped() {
        self.textField.text = ""
        self.reload()
    }

    /// Typing one character the way the keyboard does (demo).
    func type(_ character: Character) {
        self.textField.insertText(String(character))
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return false
    }

    @objc private func keyboardChanged(_ n: Notification) {
        guard let frame = n.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect, let window = self.window else { return }
        let local = window.convert(frame, to: self)
        self.keyboardHeight = max(0.0, self.bounds.height - local.minY)
        let duration = n.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double ?? 0.25
        UIView.animate(withDuration: duration) {
            self.setNeedsLayout()
            self.layoutIfNeeded()
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let width = self.bounds.width
        let top = self.window?.safeAreaInsets.top ?? self.safeAreaInsets.top
        let bottomSafe = self.window?.safeAreaInsets.bottom ?? 34.0
        self.background.frame = self.bounds
        let fieldY = top + 10.0
        if self.fieldGlass.layer.animationKeys() == nil {
            self.fieldGlass.frame = CGRect(x: 16.0, y: fieldY, width: width - 32.0 - 44.0 - 8.0, height: 44.0)
        }
        let fw = self.fieldGlass.bounds.width
        self.loupe.frame = CGRect(x: 10.0, y: 10.0, width: 24.0, height: 24.0)
        self.clearButton.frame = CGRect(x: fw - 36.0, y: 4.0, width: 36.0, height: 36.0)
        self.textField.frame = CGRect(x: 38.0, y: 0.0, width: fw - 38.0 - 36.0, height: 44.0)
        self.closeButton.frame = CGRect(x: width - 16.0 - 44.0, y: fieldY, width: 44.0, height: 44.0)

        let listTop = fieldY + 44.0 + 8.0
        self.results.frame = CGRect(x: 0.0, y: listTop, width: width, height: self.bounds.height - listTop)
        self.sectionHeader.frame = CGRect(x: 16.0, y: 0.0, width: width - 32.0, height: 28.0)
        var y: CGFloat = 28.0
        for (i, r) in self.rows.enumerated() {
            r.showsSeparator = i != self.rows.count - 1
            r.frame = CGRect(x: 0.0, y: y, width: width, height: SearchResultRow.height)
            y += SearchResultRow.height
        }
        self.results.contentSize = CGSize(width: width, height: y + 120.0)

        let keyboard = self.keyboardHeight
        let filtersHeight: CGFloat = 40.0
        let filtersY: CGFloat
        let filtersSide: CGFloat
        if keyboard > 0.0 {
            filtersSide = 12.0
            filtersY = self.bounds.height - keyboard - 8.0 - filtersHeight
        } else {
            filtersSide = 32.0
            filtersY = self.bounds.height - max(bottomSafe, 32.0) - filtersHeight
        }
        self.filters.frame = CGRect(x: filtersSide, y: filtersY, width: width - filtersSide * 2.0, height: filtersHeight)

        // Empty state: centred in the visible list area.
        let visibleBottom = filtersY - 8.0
        let ts = self.emptyTitle.sizeThatFits(CGSize(width: width - 32.0, height: 100.0))
        let bs = self.emptyText.sizeThatFits(CGSize(width: width - 32.0, height: 200.0))
        let total = ceil(ts.height) + 8.0 + ceil(bs.height)
        let ey = listTop + floor((visibleBottom - listTop - total) / 2.0)
        self.emptyTitle.frame = CGRect(x: 16.0, y: ey, width: width - 32.0, height: ceil(ts.height))
        self.emptyText.frame = CGRect(x: 16.0, y: self.emptyTitle.frame.maxY + 8.0, width: width - 32.0, height: ceil(bs.height))
    }

    var closeCenter: CGPoint { return self.closeButton.screenCenter }
    func rowCenter(_ chatId: String) -> CGPoint? {
        guard let r = self.rows.first(where: { $0.chatId == chatId }) else { return nil }
        return r.convert(CGPoint(x: r.bounds.midX, y: r.bounds.midY), to: nil)
    }
}

/// A found chat (ContactsPeerItem layout).
final class SearchResultRow: UIView {
    static let height: CGFloat = 50.0
    let chatId: String
    private let avatar: AvatarView
    private let titleLabel = UILabel()
    private let statusLabel = UILabel()
    private let separator = UIView()
    private let highlight = UIView()
    var onTap: (() -> Void)?
    var showsSeparator = true { didSet { self.separator.isHidden = !self.showsSeparator } }

    init(chat: Chat, tokens: [String]) {
        self.chatId = chat.id
        self.avatar = AvatarView(chat: chat)
        super.init(frame: .zero)
        self.backgroundColor = Theme.List.plainBackground
        self.highlight.backgroundColor = Theme.List.highlight
        self.highlight.alpha = 0.0
        self.addSubview(self.highlight)
        self.addSubview(self.avatar)
        let store = Store.shared
        let title = store.displayTitle(chat.id)
        self.titleLabel.attributedText = SearchResultRow.highlighted(title, tokens: tokens, font: Font.medium(17.0), color: Theme.List.primaryText)
        self.titleLabel.lineBreakMode = .byTruncatingTail
        self.titleLabel.applyEmojiFallback()
        self.addSubview(self.titleLabel)
        var status = store.statusText(chat)
        if store.customName(chat.id) != nil {
            status = "\(chat.originalTitle) · \(status)"
        }
        self.statusLabel.attributedText = SearchResultRow.highlighted(status, tokens: tokens, font: Font.regular(13.0), color: Theme.List.secondaryText)
        self.statusLabel.lineBreakMode = .byTruncatingTail
        self.addSubview(self.statusLabel)
        self.separator.backgroundColor = Theme.List.separator
        self.addSubview(self.separator)
        self.isAccessibilityElement = true
        self.accessibilityLabel = "\(title), \(status)"
        self.accessibilityTraits = .button
        self.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tapped)))
    }

    required init?(coder: NSCoder) { fatalError() }

    /// Matched tokens drawn in the accent colour (the prototype's highlight; Telegram's peer rows have none).
    static func highlighted(_ text: String, tokens: [String], font: UIFont, color: UIColor) -> NSAttributedString {
        let s = NSMutableAttributedString(string: text, attributes: [.font: font, .foregroundColor: color])
        for r in SearchMatcher.highlightRanges(in: text, tokens: tokens) {
            s.addAttribute(.foregroundColor, value: Theme.accent, range: r)
        }
        return s
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let size = self.bounds.size
        self.highlight.frame = self.bounds
        self.avatar.frame = CGRect(x: 15.0, y: floor((size.height - 40.0) / 2.0), width: 40.0, height: 40.0)
        self.titleLabel.frame = CGRect(x: 65.0, y: 6.0, width: size.width - 65.0 - 16.0, height: 21.0)
        self.statusLabel.frame = CGRect(x: 65.0, y: 27.0, width: size.width - 65.0 - 16.0, height: 16.0)
        self.separator.frame = CGRect(x: 65.0, y: size.height - UIScreenPixel, width: size.width - 65.0, height: UIScreenPixel)
    }

    @objc private func tapped() {
        self.highlight.alpha = 1.0
        UIView.animate(withDuration: 0.3) { self.highlight.alpha = 0.0 }
        self.onTap?()
    }
}

/// The search filter tabs: a glass capsule (corner 20) with medium 15 titles; the current one is "Chats".
final class SearchFiltersView: GlassPanelView {
    private let titles = ["Chats", "Channels", "Apps", "Posts", "Media", "Links", "Files", "Music", "Voice"]
    private let scroll = UIScrollView()
    private var labels: [UILabel] = []
    private let selection = UIView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.cornerRadius = 20.0
        self.isInteractiveGlass = true
        self.scroll.showsHorizontalScrollIndicator = false
        self.content.addSubview(self.scroll)
        self.selection.backgroundColor = UIColor(white: 0.0, alpha: 0.075)
        self.selection.layer.cornerRadius = 16.0
        self.scroll.addSubview(self.selection)
        for (i, t) in self.titles.enumerated() {
            let l = UILabel()
            l.text = t
            l.font = Font.medium(15.0)
            l.textColor = i == 0 ? Theme.accent : .black
            self.labels.append(l)
            self.scroll.addSubview(l)
        }
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layoutContent(size: CGSize) {
        self.scroll.frame = CGRect(origin: .zero, size: size)
        var x: CGFloat = 4.0
        for (i, l) in self.labels.enumerated() {
            let w = ceil(l.sizeThatFits(CGSize(width: 200.0, height: 30.0)).width) + 24.0
            l.frame = CGRect(x: x + 12.0, y: 0.0, width: w - 24.0, height: size.height)
            if i == 0 {
                self.selection.frame = CGRect(x: x, y: 4.0, width: w, height: size.height - 8.0)
            }
            x += w
        }
        self.scroll.contentSize = CGSize(width: x + 4.0, height: size.height)
    }
}
