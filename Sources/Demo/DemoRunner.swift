import UIKit

/// `-demo 1`: plays the stakeholder scenario at a calm pace through the same actions the taps trigger, with a visible
/// finger and character-by-character typing. Every step logs `DEMO <step-id> <seconds>` (stdout + Documents).
@MainActor
final class DemoRunner {
    static let shared = DemoRunner()
    private let finger = TouchIndicator.shared

    func start() {
        DemoTimeline.begin()
        Task { @MainActor in
            await self.run()
        }
    }

    private func wait(_ seconds: Double) async {
        try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }

    /// A lookup the script depends on failed: log `DEMO demo.abort <step>` (stdout + timeline) and stop.
    private struct Abort: Error {}

    private func require<T>(_ value: T?, _ step: String) throws -> T {
        guard let value else {
            DemoTimeline.mark("demo.abort \(step)")
            throw Abort()
        }
        return value
    }

    private func tap(_ point: CGPoint?, _ step: String, _ action: () -> Void) async throws {
        let point = try self.require(point, step)
        self.finger.down(at: point)
        await self.wait(0.18)
        self.finger.up()
        action()
    }

    private func longPress(_ point: CGPoint, _ action: () -> Void) async {
        self.finger.down(at: point)
        await self.wait(0.55)
        action()
        await self.wait(0.25)
        self.finger.up()
    }

    private func type(_ text: String, perCharacter: Double = 0.085, _ insert: (Character) -> Void) async {
        for ch in text {
            insert(ch)
            await self.wait(ch == " " ? perCharacter * 1.6 : perCharacter)
        }
    }

    private var nav: UINavigationController { return App.shared.navigation }
    private var chatList: ChatListController { return App.shared.chatList }
    private func top<T>(_ type: T.Type) -> T? { return self.nav.topViewController as? T }
    private func presentedRename() -> RenameController? { return self.nav.presentedViewController as? RenameController }
    private func center(_ v: UIView) -> CGPoint { return v.convert(CGPoint(x: v.bounds.midX, y: v.bounds.midY), to: nil) }

    private func mark(_ step: String) { DemoTimeline.mark(step) }

    private func run() async {
        do {
            try await self.script()
        } catch {
            // Already logged as `demo.abort <step>`.
        }
    }

    private func script() async throws {
        let target = Store.targetId
        await self.wait(0.6)

        // 1. Rename from the chat list.
        self.mark("list.before")
        await self.wait(2.2)
        let row = try self.require(self.chatList.row(target), "list.row")
        await self.longPress(self.center(row)) { self.chatList.openContextMenu(chatId: target) }
        let menu = try self.require(ContextMenuController.current, "list.menu")
        self.mark("list.menu")
        await self.wait(2.4)
        try await self.tap(menu.itemCenter(title: "Rename for me"), "list.menu.rename") {
            menu.dismiss()
            RenameController.present(chatId: target, animated: true)
        }
        await self.wait(1.0)
        let rename = try self.require(self.presentedRename(), "rename.new")
        _ = try self.require(rename.textField.isFirstResponder ? true : nil, "rename.keyboard")
        self.mark("rename.new")
        await self.wait(1.6)
        self.mark("rename.typing")
        await self.type(Store.demoCustomName) { rename.type($0) }
        self.mark("rename.filled")
        await self.wait(1.6)
        try await self.tap(rename.doneButtonCenter, "rename.done") { rename.done() }
        await self.wait(0.9)
        self.mark("list.after")
        await self.wait(3.2)

        // 2. Search by the original name.
        try await self.tap(self.center(self.chatList.searchField), "search.field") { self.chatList.activateSearch(animated: true, query: nil) }
        await self.wait(0.9)
        let search = try self.require(self.chatList.search, "search.open")
        self.mark("search.open")
        await self.wait(0.6)
        await self.type("beavers", perCharacter: 0.14) { search.type($0) }
        _ = try self.require(search.rowCenter(target), "list.search.result")
        self.mark("list.search")
        await self.wait(3.0)
        try await self.tap(search.closeCenter, "search.close") { search.deactivate() }
        await self.wait(1.0)
        self.mark("search.closed")
        await self.wait(1.2)

        // 3. The channel: header and profile.
        try await self.tap(self.center(row), "chat.open") { self.chatList.openChat(target) }
        await self.wait(0.8)
        let chat = try self.require(self.top(ChatController.self), "chat.renamed")
        self.mark("chat.renamed")
        await self.wait(2.6)
        try await self.tap(chat.titleCenter, "chat.header") { chat.openInfo() }
        await self.wait(0.8)
        let info = try self.require(self.top(PeerInfoController.self), "profile.renamed")
        self.mark("profile.renamed")
        await self.wait(3.0)

        // 4. The forwarded post in "Designers".
        try await self.tap(info.backButtonCenter, "profile.back") { App.shared.pop() }
        await self.wait(0.9)
        let chatAgain = try self.require(self.top(ChatController.self), "chat.back")
        try await self.tap(chatAgain.backCenter, "chat.back") { App.shared.pop() }
        await self.wait(0.9)
        _ = try self.require(self.nav.viewControllers.count == 1 ? true : nil, "list.back")
        self.mark("list.back")
        await self.wait(1.2)
        let designers = try self.require(self.chatList.row(Store.designersId), "designers.row")
        try await self.tap(self.center(designers), "designers.open") { self.chatList.openChat(Store.designersId) }
        await self.wait(0.8)
        let group = try self.require(self.top(ChatController.self), "forward.me")
        self.mark("forward.me")
        await self.wait(3.2)
        try await self.tap(group.forwardHeaderCenter, "forward.header") { group.openForwardSource(target) }
        await self.wait(0.8)
        let opened = try self.require(self.top(ChatController.self).flatMap { $0.chatId == target ? $0 : nil }, "forward.open")
        self.mark("forward.open")
        await self.wait(2.0)
        try await self.tap(opened.backCenter, "forward.back") { App.shared.pop() }
        await self.wait(0.9)
        let groupAgain = try self.require(self.top(ChatController.self), "designers.back")
        try await self.tap(groupAgain.backCenter, "designers.back") { App.shared.pop() }
        await self.wait(1.0)

        // 5. Reset from the profile, then undo.
        _ = try self.require(self.nav.viewControllers.count == 1 ? true : nil, "list.back2")
        self.mark("list.back2")
        await self.wait(1.0)
        try await self.tap(self.center(row), "chat.open2") { self.chatList.openChat(target) }
        await self.wait(0.9)
        let chat2 = try self.require(self.top(ChatController.self), "chat.open2")
        try await self.tap(chat2.titleCenter, "chat.header2") { chat2.openInfo() }
        await self.wait(0.9)
        let info2 = try self.require(self.top(PeerInfoController.self), "profile.renamed2")
        self.mark("profile.renamed2")
        await self.wait(1.6)
        try await self.tap(info2.editButtonCenter, "profile.edit") { info2.openRename() }
        await self.wait(1.0)
        let edit = try self.require(self.presentedRename(), "rename.edit")
        self.mark("rename.edit")
        await self.wait(1.8)
        try await self.tap(edit.clearButtonCenter, "rename.clear") { edit.clearTapped() }
        self.mark("rename.cleared")
        await self.wait(1.8)
        try await self.tap(edit.doneButtonCenter, "rename.done2") { edit.done() }
        await self.wait(0.9)
        let toast = try self.require(UndoToast.current, "profile.restored")
        self.mark("profile.restored")
        await self.wait(2.4)
        try await self.tap(toast.undoCenter, "profile.undo") { toast.undoTapped() }
        await self.wait(0.6)
        _ = try self.require(Store.shared.customName(target), "profile.undo")
        self.mark("profile.undo")
        await self.wait(3.0)
        self.mark("demo.end")
    }
}
