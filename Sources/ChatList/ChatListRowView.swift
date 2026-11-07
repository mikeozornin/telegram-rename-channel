import UIKit
import Display

/// One chat-list row, laid out as ChatListUI/Sources/Node/ChatListItem.swift does at the default text size:
/// avatar 60 at x=16 (avatarLeftEdgeInset, :2729), content rect x = 2 + 24 + 60 = 86 (:4284, :2746), y = 8,
/// width = width - 84 - 18 (:3898); title semibold 16, preview regular 15 (two lines), date regular 14 (:2458-2462),
/// date at contentRect.minY + 2 (:4792), badge 20 high at contentRect.maxY - 20 - 4 (:4856-4859), height 76.
final class ChatListRowView: UIView {
    static let height: CGFloat = 76.0

    let chatId: String
    private let avatar: AvatarView
    private let titleLabel = UILabel()
    private let textLabel = UILabel()
    private let dateLabel = UILabel()
    private let mutedIcon = UIImageView()
    private let badge = UIView()
    private let badgeLabel = UILabel()
    private let separator = UIView()
    private let highlight = UIView()
    private let checks = UIImageView()

    var onTap: (() -> Void)?
    var onLongPress: (() -> Void)?
    var showsSeparator = true { didSet { self.separator.isHidden = !self.showsSeparator } }

    init(chat: Chat) {
        self.chatId = chat.id
        self.avatar = AvatarView(chat: chat)
        super.init(frame: .zero)
        self.backgroundColor = Theme.ChatList.background
        self.highlight.backgroundColor = Theme.List.highlight
        self.highlight.alpha = 0.0
        self.addSubview(self.highlight)
        self.addSubview(self.avatar)

        self.titleLabel.font = Font.semibold(16.0)
        self.titleLabel.textColor = Theme.ChatList.title
        self.titleLabel.lineBreakMode = .byTruncatingTail
        self.addSubview(self.titleLabel)

        self.textLabel.numberOfLines = 2
        self.textLabel.lineBreakMode = .byTruncatingTail
        self.addSubview(self.textLabel)

        self.dateLabel.font = Font.regular(14.0)
        self.dateLabel.textColor = Theme.ChatList.date
        self.dateLabel.text = chat.time
        self.addSubview(self.dateLabel)

        self.mutedIcon.image = icon("Chat List/PeerMutedIcon", Theme.ChatList.muteIcon)
        self.mutedIcon.isHidden = !chat.muted
        self.addSubview(self.mutedIcon)

        self.badge.backgroundColor = chat.muted ? Theme.ChatList.unreadBadgeMuted : Theme.ChatList.unreadBadge
        self.badge.layer.cornerRadius = 10.0
        self.badge.isHidden = chat.unread == 0
        self.badgeLabel.font = Font.with(size: 12.0, design: .regular, weight: .semibold, traits: [.monospacedNumbers])
        self.badgeLabel.textColor = .white
        self.badgeLabel.textAlignment = .center
        self.badgeLabel.text = "\(chat.unread)"
        self.badge.addSubview(self.badgeLabel)
        self.addSubview(self.badge)

        self.separator.backgroundColor = Theme.ChatList.separator
        self.addSubview(self.separator)

        self.setPreview(chat: chat)
        self.update(title: Store.shared.displayTitle(chat.id))

        self.isAccessibilityElement = true
        self.accessibilityTraits = .button

        let tap = UITapGestureRecognizer(target: self, action: #selector(self.tapped))
        let long = UILongPressGestureRecognizer(target: self, action: #selector(self.longPressed(_:)))
        long.minimumPressDuration = 0.4
        tap.require(toFail: long)
        self.addGestureRecognizer(tap)
        self.addGestureRecognizer(long)
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setPreview(chat: Chat) {
        let text = NSMutableAttributedString()
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byTruncatingTail
        if let author = chat.author {
            // Group preview: the author's name on the first line (authorNameColor), the message after it (:3036).
            text.append(NSAttributedString(string: author + "\n", attributes: [.font: Font.regular(15.0), .foregroundColor: Theme.ChatList.author]))
        }
        let flattened = chat.preview.components(separatedBy: .newlines).filter { !$0.isEmpty }.joined(separator: " ")
        text.append(NSAttributedString(string: flattened, attributes: [.font: Font.regular(15.0), .foregroundColor: Theme.ChatList.preview]))
        self.textLabel.attributedText = text
        self.textLabel.applyEmojiFallback()
    }

    func update(title: String) {
        self.titleLabel.text = title
        self.titleLabel.applyEmojiFallback()
        self.accessibilityLabel = title
        self.setNeedsLayout()
    }

    func setHighlighted(_ value: Bool, animated: Bool) {
        UIView.animate(withDuration: animated ? (value ? 0.05 : 0.3) : 0.0) {
            self.highlight.alpha = value ? 1.0 : 0.0
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let width = self.bounds.width
        let height = self.bounds.height
        self.highlight.frame = self.bounds
        self.avatar.frame = CGRect(x: 16.0, y: floor((height - 60.0) / 2.0), width: 60.0, height: 60.0)
        let contentRect = CGRect(x: 86.0, y: 8.0, width: width - 84.0 - 18.0, height: height - 21.0)

        let dateSize = self.dateLabel.sizeThatFits(CGSize(width: 200.0, height: 30.0))
        self.dateLabel.frame = CGRect(x: contentRect.maxX - ceil(dateSize.width), y: contentRect.minY + 2.0, width: ceil(dateSize.width), height: ceil(dateSize.height))

        var titleMaxWidth = contentRect.width - ceil(dateSize.width) - 6.0
        if !self.mutedIcon.isHidden, let image = self.mutedIcon.image {
            titleMaxWidth -= image.size.width + 4.0
        }
        let titleSize = self.titleLabel.sizeThatFits(CGSize(width: titleMaxWidth, height: 30.0))
        let titleWidth = min(titleMaxWidth, ceil(titleSize.width))
        self.titleLabel.frame = CGRect(x: contentRect.minX, y: contentRect.minY + UIScreenPixel, width: titleWidth, height: ceil(titleSize.height))
        if let image = self.mutedIcon.image {
            self.mutedIcon.frame = CGRect(x: self.titleLabel.frame.maxX + 4.0, y: floorToScreenPixels(self.titleLabel.frame.midY - image.size.height / 2.0), width: image.size.width, height: image.size.height)
        }

        var textRight = contentRect.maxX
        if !self.badge.isHidden {
            let labelWidth = ceil(self.badgeLabel.sizeThatFits(CGSize(width: 100.0, height: 20.0)).width)
            let badgeWidth = max(20.0, labelWidth + 12.0)
            self.badge.frame = CGRect(x: contentRect.maxX - badgeWidth, y: contentRect.maxY - 20.0 - 4.0, width: badgeWidth, height: 20.0)
            self.badgeLabel.frame = self.badge.bounds
            textRight = self.badge.frame.minX - 6.0
        }
        let textWidth = textRight - contentRect.minX + 1.0
        let textSize = self.textLabel.sizeThatFits(CGSize(width: textWidth, height: 60.0))
        self.textLabel.frame = CGRect(x: contentRect.minX - 1.0, y: contentRect.minY + ceil(titleSize.height) - 2.0 + 1.0, width: textWidth, height: min(ceil(textSize.height), 38.0))

        self.separator.frame = CGRect(x: 86.0, y: height - UIScreenPixel, width: width - 86.0, height: UIScreenPixel)
    }

    @objc private func tapped() {
        self.setHighlighted(true, animated: false)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            self.setHighlighted(false, animated: true)
        }
        self.onTap?()
    }

    @objc private func longPressed(_ g: UILongPressGestureRecognizer) {
        switch g.state {
        case .began:
            self.onLongPress?()
        default:
            break
        }
    }
}
