import UIKit
import Display

/// One message row. Bubble metrics: text regular 17, insets top 6 / bottom 6 / sides 11 (ChatMessageItemView.swift:22-35),
/// corner 16 with a tail on the bottom (ChatMessageBubbleImages.swift), max width W - 36 (ChatMessageItemCommon.swift:11-17),
/// group avatar 34 in a 38 column for incoming messages, author semibold 14 (ChatMessageBubbleItemNode.swift:1779),
/// time regular 11 (ChatMessageDateAndStatusNode.swift:620). Forward header (ChatMessageForwardInfoNode.swift):
/// "Forwarded from" regular 14 over the name medium 14, both in the bubble's accent text colour.
final class MessageBubbleView: UIView {
    let message: DemoMessage
    let isChannelPost: Bool
    private let bubble = BubbleShapeView()
    private let authorLabel = UILabel()
    private let forwardPrefix = UILabel()
    private let forwardName = UILabel()
    private let forwardTapArea = UIView()
    private let textLabel = UILabel()
    private let timeLabel = UILabel()
    private let viewsIcon = UIImageView()
    private let checks = UIImageView()
    private var avatar: AvatarView?
    private let shareButton = UIView()
    var onForwardTap: ((String) -> Void)?
    /// Merged with the previous / next message of the same author (ChatMessageBubbleImages.swift:87-117).
    var mergedWithPrevious = false { didSet { self.authorLabel.isHidden = self.mergedWithPrevious; self.bubble.mergedTop = self.mergedWithPrevious } }
    var mergedWithNext = false { didSet { self.bubble.hasTail = !self.mergedWithNext } }

    private var isOutgoing: Bool { return self.message.author == nil && !self.isChannelPost }

    init(message: DemoMessage, isChannelPost: Bool) {
        self.message = message
        self.isChannelPost = isChannelPost
        super.init(frame: .zero)
        self.addSubview(self.bubble)
        self.bubble.fillColor = self.isOutgoing ? Theme.Bubble.outgoing : Theme.Bubble.incoming
        self.bubble.isOutgoing = self.isOutgoing

        if let author = message.author, !isChannelPost {
            self.authorLabel.text = author
            self.authorLabel.font = Font.semibold(14.0)
            self.authorLabel.textColor = message.authorColor
            self.addSubview(self.authorLabel)
        }
        if let (color, initials) = message.avatar {
            let a = AvatarView(colorIndex: color, initials: initials)
            self.avatar = a
            self.addSubview(a)
        }
        let accent = self.isOutgoing ? Theme.Bubble.outgoingAccent : Theme.Bubble.incomingAccent
        if message.forward != nil {
            self.forwardPrefix.text = "Forwarded from"
            self.forwardPrefix.font = Font.regular(14.0)
            self.forwardPrefix.textColor = accent
            self.forwardName.font = Font.medium(14.0)
            self.forwardName.textColor = accent
            self.forwardName.lineBreakMode = .byTruncatingTail
            self.addSubview(self.forwardPrefix)
            self.addSubview(self.forwardName)
            self.forwardTapArea.isAccessibilityElement = true
            self.forwardTapArea.accessibilityTraits = .link
            self.forwardTapArea.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.forwardTapped)))
            self.addSubview(self.forwardTapArea)
        }
        self.textLabel.numberOfLines = 0
        self.textLabel.font = Font.regular(17.0)
        self.textLabel.textColor = .black
        let body = NSMutableAttributedString(string: message.text, attributes: [.font: Font.regular(17.0), .foregroundColor: UIColor.black])
        // Links in the accent text colour, as Telegram draws them.
        if let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) {
            let linkColor = self.isOutgoing ? Theme.Bubble.outgoingAccent : Theme.Bubble.incomingAccent
            for match in detector.matches(in: message.text, range: NSRange(location: 0, length: (message.text as NSString).length)) {
                body.addAttribute(.foregroundColor, value: linkColor, range: match.range)
            }
        }
        self.textLabel.attributedText = body
        self.textLabel.applyEmojiFallback()
        self.addSubview(self.textLabel)

        self.timeLabel.font = Font.regular(11.0)
        let secondary = self.isOutgoing ? Theme.Bubble.outgoingSecondary : Theme.Bubble.incomingSecondary
        self.timeLabel.textColor = secondary
        if let views = message.views {
            self.timeLabel.text = "\(views)  \(message.time)"
            self.viewsIcon.image = icon("Chat/Message/ImpressionCount", secondary)
            self.addSubview(self.viewsIcon)
        } else {
            self.timeLabel.text = message.time
        }
        self.addSubview(self.timeLabel)
        if self.isOutgoing {
            self.checks.image = MessageBubbleView.doubleCheck(color: secondary)
            self.addSubview(self.checks)
        }
        if isChannelPost {
            // The post's share button beside the bubble.
            self.shareButton.backgroundColor = Theme.Bubble.service
            self.shareButton.layer.cornerRadius = 15.0
            let i = UIImageView(image: icon("Chat/Message/ShareIcon", .white))
            i.contentMode = .center
            i.frame = CGRect(x: 0.0, y: 0.0, width: 30.0, height: 30.0)
            self.shareButton.addSubview(i)
            self.addSubview(self.shareButton)
        }
        self.refreshForward(viewer: .me)
    }

    required init?(coder: NSCoder) { fatalError() }

    func refreshForward(viewer: ChatViewer) {
        guard case let .channel(id)? = self.message.forward else { return }
        // Everyone else sees the original name; the viewer who renamed it sees their own name.
        let name = viewer == .me ? Store.shared.displayTitle(id) : (Store.shared.chat(id)?.originalTitle ?? "")
        self.forwardName.text = name
        self.forwardName.applyEmojiFallback()
        self.forwardTapArea.accessibilityLabel = "Forwarded from \(name)"
        self.setNeedsLayout()
    }

    @objc private func forwardTapped() {
        if case let .channel(id)? = self.message.forward {
            self.onForwardTap?(id)
        }
    }

    private var lastWidth: CGFloat = 0.0
    private var computed: (bubble: CGRect, height: CGFloat) = (.zero, 0.0)

    /// Computes the frames for `width` and returns the row height.
    func layout(width: CGFloat) -> CGFloat {
        let hasAvatarColumn = !self.isChannelPost && !self.isOutgoing && self.message.avatar != nil
        let avatarColumn: CGFloat = hasAvatarColumn ? 38.0 : 0.0
        let sideMargin: CGFloat = 9.0
        var maxBubble = width - 36.0 - avatarColumn
        if self.isChannelPost { maxBubble = width - 45.0 - sideMargin }
        let inner = maxBubble - 22.0

        let timeSize = self.timeLabel.sizeThatFits(CGSize(width: 200.0, height: 20.0))
        var statusWidth = ceil(timeSize.width)
        if self.viewsIcon.image != nil { statusWidth += (self.viewsIcon.image?.size.width ?? 0.0) + 3.0 }
        if self.isOutgoing { statusWidth += 19.0 }

        var y: CGFloat = 6.0
        var contentWidth: CGFloat = 0.0
        var authorFrame = CGRect.zero
        if self.authorLabel.superview != nil && !self.mergedWithPrevious {
            let s = self.authorLabel.sizeThatFits(CGSize(width: inner, height: 20.0))
            authorFrame = CGRect(x: 11.0, y: y, width: min(inner, ceil(s.width)), height: ceil(s.height))
            contentWidth = max(contentWidth, authorFrame.width)
            y = authorFrame.maxY + 1.0
        }
        var prefixFrame = CGRect.zero
        var nameFrame = CGRect.zero
        if self.forwardPrefix.superview != nil {
            let ps = self.forwardPrefix.sizeThatFits(CGSize(width: inner, height: 20.0))
            prefixFrame = CGRect(x: 11.0, y: y, width: ceil(ps.width), height: ceil(ps.height))
            let ns = self.forwardName.sizeThatFits(CGSize(width: inner, height: 20.0))
            nameFrame = CGRect(x: 11.0, y: prefixFrame.maxY, width: min(inner, ceil(ns.width)), height: ceil(ns.height))
            contentWidth = max(contentWidth, prefixFrame.width, nameFrame.width)
            y = nameFrame.maxY + 3.0
        }
        let textSize = self.textLabel.sizeThatFits(CGSize(width: inner, height: 2000.0))
        // Fit the time on the last line when there is room, else below.
        let lastLineRoom = inner - ceil(textSize.width)
        let lineHeight = Font.regular(17.0).lineHeight
        var textFrame = CGRect(x: 11.0, y: y, width: ceil(textSize.width), height: ceil(textSize.height))
        contentWidth = max(contentWidth, textFrame.width)
        var bubbleHeight: CGFloat
        let singleLine = textSize.height < lineHeight * 1.5
        if singleLine && lastLineRoom > statusWidth + 8.0 {
            contentWidth = max(contentWidth, textFrame.width + statusWidth + 8.0)
            bubbleHeight = textFrame.maxY + 6.0
        } else {
            bubbleHeight = textFrame.maxY + 6.0 + (singleLine ? 0.0 : 14.0)
            if singleLine {
                bubbleHeight += 14.0
            }
            contentWidth = max(contentWidth, statusWidth)
        }
        textFrame.size.width = max(textFrame.width, 1.0)
        let bubbleWidth = min(maxBubble, contentWidth + 22.0)
        let bubbleX: CGFloat = self.isOutgoing ? width - sideMargin - bubbleWidth : sideMargin + avatarColumn
        let bubbleFrame = CGRect(x: bubbleX, y: 0.0, width: bubbleWidth, height: bubbleHeight)

        self.bubble.frame = bubbleFrame.insetBy(dx: -6.0, dy: 0.0)
        self.bubble.bodyInset = 6.0
        self.authorLabel.frame = authorFrame.offsetBy(dx: bubbleX, dy: 0.0)
        self.forwardPrefix.frame = prefixFrame.offsetBy(dx: bubbleX, dy: 0.0)
        self.forwardName.frame = nameFrame.offsetBy(dx: bubbleX, dy: 0.0)
        self.forwardTapArea.frame = prefixFrame.union(nameFrame).insetBy(dx: -6.0, dy: -3.0).offsetBy(dx: bubbleX, dy: 0.0)
        self.textLabel.frame = textFrame.offsetBy(dx: bubbleX, dy: 0.0)

        let statusRight = bubbleFrame.maxX - 11.0 + 4.0
        let statusY = bubbleFrame.maxY - 6.0 - ceil(timeSize.height) + 2.0
        var x = statusRight
        if self.isOutgoing {
            self.checks.frame = CGRect(x: x - 16.0, y: statusY + 1.0, width: 16.0, height: 11.0)
            x -= 19.0
        }
        self.timeLabel.frame = CGRect(x: x - ceil(timeSize.width), y: statusY, width: ceil(timeSize.width), height: ceil(timeSize.height))
        if let image = self.viewsIcon.image {
            self.viewsIcon.frame = CGRect(x: self.timeLabel.frame.minX - image.size.width - 3.0, y: floorToScreenPixels(self.timeLabel.frame.midY - image.size.height / 2.0), width: image.size.width, height: image.size.height)
        }
        if let a = self.avatar {
            a.frame = CGRect(x: sideMargin - 3.0, y: bubbleFrame.maxY - 34.0, width: 34.0, height: 34.0)
            a.isHidden = !hasAvatarColumn || self.mergedWithNext
        }
        self.shareButton.frame = CGRect(x: bubbleFrame.maxX + 8.0, y: bubbleFrame.maxY - 30.0, width: 30.0, height: 30.0)
        return bubbleHeight
    }

    var forwardHeaderCenter: CGPoint? {
        guard self.forwardPrefix.superview != nil else { return nil }
        return self.forwardTapArea.convert(CGPoint(x: self.forwardTapArea.bounds.midX, y: self.forwardTapArea.bounds.midY), to: nil)
    }

    static func doubleCheck(color: UIColor) -> UIImage? {
        return generateImage(CGSize(width: 16.0, height: 11.0), rotatedContext: { size, context in
            context.clear(CGRect(origin: .zero, size: size))
            context.setStrokeColor(color.cgColor)
            context.setLineWidth(1.33)
            context.setLineCap(.round)
            context.setLineJoin(.round)
            context.move(to: CGPoint(x: 1.0, y: 6.0)); context.addLine(to: CGPoint(x: 4.0, y: 9.0)); context.addLine(to: CGPoint(x: 10.0, y: 2.0))
            context.move(to: CGPoint(x: 7.5, y: 8.5)); context.addLine(to: CGPoint(x: 8.0, y: 9.0)); context.addLine(to: CGPoint(x: 14.5, y: 2.0))
            context.strokePath()
        })
    }
}

/// A bubble body (corner 16) with Telegram's tail at the bottom corner on the sender's side.
final class BubbleShapeView: UIView {
    var fillColor: UIColor = .white { didSet { self.setNeedsDisplay() } }
    var isOutgoing = false { didSet { self.setNeedsDisplay() } }
    var hasTail = true { didSet { self.setNeedsDisplay() } }
    var mergedTop = false { didSet { self.setNeedsDisplay() } }
    var bodyInset: CGFloat = 6.0

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.isOpaque = false
        self.contentMode = .redraw
        self.isUserInteractionEnabled = false
        self.layer.shadowColor = UIColor.black.cgColor
        self.layer.shadowOpacity = 0.06
        self.layer.shadowRadius = 0.5
        self.layer.shadowOffset = CGSize(width: 0.0, height: 0.5)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ rect: CGRect) {
        let body = self.bounds.insetBy(dx: self.bodyInset, dy: 0.0)
        let r: CGFloat = 16.0
        // Merged runs: the sender-side corners shrink to 8 (top when merged above, bottom when merged below).
        let small: CGFloat = 8.0
        let senderTop = self.mergedTop ? small : r
        if !self.hasTail {
            let radii: (tl: CGFloat, tr: CGFloat, bl: CGFloat, br: CGFloat) = self.isOutgoing ? (r, senderTop, r, small) : (senderTop, r, small, r)
            let p = UIBezierPath()
            p.move(to: CGPoint(x: body.minX + radii.tl, y: body.minY))
            p.addLine(to: CGPoint(x: body.maxX - radii.tr, y: body.minY))
            p.addArc(withCenter: CGPoint(x: body.maxX - radii.tr, y: body.minY + radii.tr), radius: radii.tr, startAngle: -.pi / 2, endAngle: 0, clockwise: true)
            p.addLine(to: CGPoint(x: body.maxX, y: body.maxY - radii.br))
            p.addArc(withCenter: CGPoint(x: body.maxX - radii.br, y: body.maxY - radii.br), radius: radii.br, startAngle: 0, endAngle: .pi / 2, clockwise: true)
            p.addLine(to: CGPoint(x: body.minX + radii.bl, y: body.maxY))
            p.addArc(withCenter: CGPoint(x: body.minX + radii.bl, y: body.maxY - radii.bl), radius: radii.bl, startAngle: .pi / 2, endAngle: .pi, clockwise: true)
            p.addLine(to: CGPoint(x: body.minX, y: body.minY + radii.tl))
            p.addArc(withCenter: CGPoint(x: body.minX + radii.tl, y: body.minY + radii.tl), radius: radii.tl, startAngle: .pi, endAngle: -.pi / 2, clockwise: true)
            p.close()
            self.fillColor.setFill()
            p.fill()
            return
        }
        let path = UIBezierPath()
        if self.isOutgoing {
            path.move(to: CGPoint(x: body.minX + r, y: body.minY))
            path.addLine(to: CGPoint(x: body.maxX - senderTop, y: body.minY))
            path.addArc(withCenter: CGPoint(x: body.maxX - senderTop, y: body.minY + senderTop), radius: senderTop, startAngle: -.pi / 2, endAngle: 0, clockwise: true)
            path.addLine(to: CGPoint(x: body.maxX, y: body.maxY - 8.0))
            // tail
            path.addQuadCurve(to: CGPoint(x: body.maxX + 6.0, y: body.maxY), controlPoint: CGPoint(x: body.maxX, y: body.maxY - 1.0))
            path.addQuadCurve(to: CGPoint(x: body.maxX - 10.0, y: body.maxY - 3.0), controlPoint: CGPoint(x: body.maxX - 4.0, y: body.maxY + 0.5))
            path.addQuadCurve(to: CGPoint(x: body.maxX - r - 2.0, y: body.maxY), controlPoint: CGPoint(x: body.maxX - 13.0, y: body.maxY))
            path.addLine(to: CGPoint(x: body.minX + r, y: body.maxY))
            path.addArc(withCenter: CGPoint(x: body.minX + r, y: body.maxY - r), radius: r, startAngle: .pi / 2, endAngle: .pi, clockwise: true)
            path.addLine(to: CGPoint(x: body.minX, y: body.minY + r))
            path.addArc(withCenter: CGPoint(x: body.minX + r, y: body.minY + r), radius: r, startAngle: .pi, endAngle: -.pi / 2, clockwise: true)
        } else {
            path.move(to: CGPoint(x: body.maxX - r, y: body.minY))
            path.addArc(withCenter: CGPoint(x: body.maxX - r, y: body.minY + r), radius: r, startAngle: -.pi / 2, endAngle: 0, clockwise: true)
            path.addLine(to: CGPoint(x: body.maxX, y: body.maxY - r))
            path.addArc(withCenter: CGPoint(x: body.maxX - r, y: body.maxY - r), radius: r, startAngle: 0, endAngle: .pi / 2, clockwise: true)
            path.addLine(to: CGPoint(x: body.minX + r + 2.0, y: body.maxY))
            path.addQuadCurve(to: CGPoint(x: body.minX + 10.0, y: body.maxY - 3.0), controlPoint: CGPoint(x: body.minX + 13.0, y: body.maxY))
            path.addQuadCurve(to: CGPoint(x: body.minX - 6.0, y: body.maxY), controlPoint: CGPoint(x: body.minX + 4.0, y: body.maxY + 0.5))
            path.addQuadCurve(to: CGPoint(x: body.minX, y: body.maxY - 8.0), controlPoint: CGPoint(x: body.minX, y: body.maxY - 1.0))
            path.addLine(to: CGPoint(x: body.minX, y: body.minY + senderTop))
            path.addArc(withCenter: CGPoint(x: body.minX + senderTop, y: body.minY + senderTop), radius: senderTop, startAngle: .pi, endAngle: -.pi / 2, clockwise: true)
        }
        path.close()
        self.fillColor.setFill()
        path.fill()
    }
}
