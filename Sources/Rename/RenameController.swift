import UIKit
import Display

/// "Custom name" screen: an ItemList-style glass screen (ItemListSystemStyle.glass, as PeerInfo's lists).
/// Metrics: ItemListUI/Sources/Items/ItemListSingleLineInputItem.swift (font regular 17, vertical inset 15 → 52 pt,
/// text inset 16, clear button 38 wide, "Components/Search Bar/Clear" tinted 0x7b7b81), ItemListActionItem.swift
/// (regular 17, accent, 52 pt, leading), ItemListTextItem.swift (footer regular 13, 0x6d6d72, left 15, top 7),
/// ItemListItem.swift:97-128 (first block top 24, between blocks 35), ItemListControllerNode.swift:657 (side 16),
/// PresentationResourcesItemList.swift:391 (glass corner radius 26).
final class RenameController: UIViewController, UITextFieldDelegate {
    static let maxLength = 64

    let chatId: String
    private let original: String
    private let initial: String
    private let header = GlassNavHeader()
    private let cancelButton = GlassButton(title: "Cancel")
    private let doneButton = GlassButton(title: "Done", accent: true)
    private let block = UIView()
    let textField = UITextField()
    private let clearButton = UIButton(type: .custom)
    private let counter = UILabel()
    private let footer = UILabel()
    private let resetBlock = UIView()
    private let resetLabel = UILabel()
    private let resetHighlight = UIView()

    var onFinish: (() -> Void)?

    @discardableResult
    static func present(chatId: String, animated: Bool) -> RenameController {
        let vc = RenameController(chatId: chatId)
        vc.modalPresentationStyle = .pageSheet
        if let sheet = vc.sheetPresentationController {
            sheet.detents = [.large()]
            sheet.prefersGrabberVisible = false
        }
        // The sheet's presentation shows the window behind the presenting screen: give it that screen's colour.
        App.shared.setSeamColor(App.background(of: App.shared.navigation.topViewController))
        App.shared.presenter.present(vc, animated: animated) {
            App.shared.bringOverlaysToFront()
        }
        return vc
    }

    init(chatId: String) {
        self.chatId = chatId
        let chat = Store.shared.chat(chatId)!
        self.original = chat.originalTitle
        self.initial = Store.shared.customName(chatId) ?? ""
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    private var hasCustomName: Bool { return !self.initial.isEmpty }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = Theme.List.blocksBackground
        let chat = Store.shared.chat(self.chatId)!

        self.block.backgroundColor = Theme.List.itemBlocksBackground
        self.block.layer.cornerRadius = 26.0
        self.block.layer.cornerCurve = .continuous
        self.view.addSubview(self.block)

        self.textField.font = Font.regular(17.0)
        self.textField.textColor = Theme.List.primaryText
        self.textField.tintColor = Theme.accent
        self.textField.attributedPlaceholder = NSAttributedString(string: self.original, attributes: [.font: Font.regular(17.0), .foregroundColor: Theme.List.placeholder])
        self.textField.text = self.initial
        self.textField.autocorrectionType = .no
        self.textField.autocapitalizationType = .sentences
        self.textField.returnKeyType = .done
        self.textField.clearButtonMode = .never
        self.textField.delegate = self
        self.textField.accessibilityLabel = "Custom name"
        self.textField.addTarget(self, action: #selector(self.textChanged), for: .editingChanged)
        self.block.addSubview(self.textField)

        self.clearButton.setImage(icon("Components/Search Bar/Clear", UIColor(rgb: 0x7b7b81)), for: .normal)
        self.clearButton.accessibilityLabel = "Clear"
        self.clearButton.addTarget(self, action: #selector(self.clearTapped), for: .touchUpInside)
        self.block.addSubview(self.clearButton)

        self.counter.font = Font.regular(13.0)
        self.counter.textColor = Theme.List.secondaryText
        self.counter.textAlignment = .right
        self.block.addSubview(self.counter)

        self.footer.numberOfLines = 0
        let members = chat.kind == .group ? "Members" : "Subscribers"
        self.footer.attributedText = NSAttributedString(string: "Only you will see this name, on all your devices. \(members) see “\(self.original)”.", attributes: [.font: Font.regular(13.0), .foregroundColor: Theme.List.freeText])
        self.view.addSubview(self.footer)

        self.resetBlock.backgroundColor = Theme.List.itemBlocksBackground
        self.resetBlock.layer.cornerRadius = 26.0
        self.resetBlock.layer.cornerCurve = .continuous
        self.resetBlock.clipsToBounds = true
        self.resetBlock.isHidden = !self.hasCustomName
        self.resetHighlight.backgroundColor = Theme.List.highlight
        self.resetHighlight.alpha = 0.0
        self.resetBlock.addSubview(self.resetHighlight)
        self.resetLabel.text = "Reset to original name"
        self.resetLabel.font = Font.regular(17.0)
        self.resetLabel.textColor = Theme.accent
        self.resetBlock.addSubview(self.resetLabel)
        self.resetBlock.isAccessibilityElement = true
        self.resetBlock.accessibilityLabel = "Reset to original name"
        self.resetBlock.accessibilityTraits = .button
        self.resetBlock.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.resetTapped)))
        self.view.addSubview(self.resetBlock)

        self.header.title = "Custom name"
        self.header.leftButton = self.cancelButton
        self.header.rightButton = self.doneButton
        self.doneButton.isAccentFilled = true
        self.cancelButton.onTap = { [weak self] in self?.cancel() }
        self.doneButton.onTap = { [weak self] in self?.done() }
        self.view.addSubview(self.header)

        self.updateState()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        App.shared.bringOverlaysToFront()
        self.textField.becomeFirstResponder()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let width = self.view.bounds.width
        self.header.frame = CGRect(x: 0.0, y: 0.0, width: width, height: GlassNavHeader.sheetHeight)
        let side: CGFloat = 16.0
        var y = GlassNavHeader.sheetHeight + 24.0
        let rowHeight: CGFloat = 52.0
        self.block.frame = CGRect(x: side, y: y, width: width - side * 2.0, height: rowHeight)
        let blockWidth = self.block.bounds.width
        self.clearButton.frame = CGRect(x: blockWidth - 38.0, y: 0.0, width: 38.0, height: rowHeight)
        let counterWidth: CGFloat = self.counter.isHidden ? 0.0 : 28.0
        self.counter.frame = CGRect(x: blockWidth - 38.0 - counterWidth, y: 0.0, width: counterWidth, height: rowHeight)
        self.textField.frame = CGRect(x: 16.0, y: 0.0, width: blockWidth - 16.0 - 38.0 - counterWidth - (counterWidth > 0 ? 6.0 : 0.0), height: rowHeight)
        y += rowHeight
        let footerSize = self.footer.sizeThatFits(CGSize(width: width - side * 2.0 - 15.0 * 2.0, height: 200.0))
        self.footer.frame = CGRect(x: side + 15.0, y: y + 7.0, width: width - side * 2.0 - 30.0, height: ceil(footerSize.height))
        y = self.footer.frame.maxY + 7.0 + 16.0
        self.resetBlock.frame = CGRect(x: side, y: y, width: width - side * 2.0, height: rowHeight)
        self.resetHighlight.frame = self.resetBlock.bounds
        self.resetLabel.frame = CGRect(x: 16.0, y: 0.0, width: self.resetBlock.bounds.width - 32.0, height: rowHeight)
    }

    // MARK: - State

    private var currentText: String {
        return (self.textField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// The custom name the field would store: nil when it is empty or exactly the original title (both reset).
    private var effectiveNewValue: String? {
        let text = self.currentText
        return (text.isEmpty || text == self.original) ? nil : text
    }

    /// Done is enabled only when saving would change what the user sees (the field differs from the displayed name).
    private var hasChanges: Bool {
        let current: String? = self.initial.isEmpty ? nil : self.initial
        return self.effectiveNewValue != current
    }

    private func updateState() {
        let length = (self.textField.text ?? "").count
        let remaining = RenameController.maxLength - length
        self.counter.isHidden = remaining > 10
        self.counter.text = "\(remaining)"
        self.clearButton.isHidden = length == 0
        self.doneButton.isEnabledAccent = self.hasChanges
        self.view.setNeedsLayout()
    }

    func setText(_ text: String) {
        self.loadViewIfNeeded()
        self.textField.text = String(text.prefix(RenameController.maxLength))
        self.updateState()
    }

    /// Typing one character the way the keyboard does (used by the demo's simulated typing).
    func type(_ character: Character) {
        if !self.textField.isFirstResponder { self.textField.becomeFirstResponder() }
        let current = self.textField.text ?? ""
        guard current.count < RenameController.maxLength else { return }
        self.textField.insertText(String(character))
    }

    @objc private func textChanged() {
        if let text = self.textField.text, text.count > RenameController.maxLength {
            self.textField.text = String(text.prefix(RenameController.maxLength))
        }
        self.updateState()
    }

    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        let current = (textField.text ?? "") as NSString
        let updated = current.replacingCharacters(in: range, with: string)
        if updated.count <= RenameController.maxLength {
            return true
        }
        // Max 64, no error: typing past it does nothing; a longer paste inserts the part that fits.
        let room = RenameController.maxLength - current.replacingCharacters(in: range, with: "").count
        guard room > 0 else { return false }
        let fitted = String(string.prefix(room))
        textField.text = current.replacingCharacters(in: range, with: fitted)
        if let position = textField.position(from: textField.beginningOfDocument, offset: range.location + (fitted as NSString).length) {
            textField.selectedTextRange = textField.textRange(from: position, to: position)
        }
        self.updateState()
        return false
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if self.hasChanges { self.done() }
        return false
    }

    @objc func clearTapped() {
        self.textField.text = ""
        self.updateState()
        self.textField.becomeFirstResponder()
    }

    // MARK: - Actions

    func cancel() {
        self.textField.resignFirstResponder()
        self.dismiss(animated: true)
    }

    func done() {
        guard self.hasChanges else { return }
        self.commit(self.effectiveNewValue)
    }

    @objc func resetTapped() {
        UIView.animate(withDuration: 0.05, animations: { self.resetHighlight.alpha = 1.0 }, completion: { _ in
            UIView.animate(withDuration: 0.3) { self.resetHighlight.alpha = 0.0 }
        })
        self.commit(nil)
    }

    private func commit(_ value: String?) {
        let previous = Store.shared.customName(self.chatId)
        let chatId = self.chatId
        self.textField.resignFirstResponder()
        Store.shared.setCustomName(chatId, value)
        self.dismiss(animated: true) {
            let text = value == nil ? "Original name restored" : "Name changed. Only you can see it."
            UndoToast.show(text: text, undo: {
                Store.shared.setCustomName(chatId, previous)
            })
        }
    }

    var resetRowCenter: CGPoint {
        return self.resetBlock.convert(CGPoint(x: self.resetBlock.bounds.midX, y: self.resetBlock.bounds.midY), to: nil)
    }
    var clearButtonCenter: CGPoint {
        return self.clearButton.convert(CGPoint(x: self.clearButton.bounds.midX, y: self.clearButton.bounds.midY), to: nil)
    }
    var doneButtonCenter: CGPoint {
        return self.doneButton.convert(CGPoint(x: self.doneButton.bounds.midX, y: self.doneButton.bounds.midY), to: nil)
    }
}
