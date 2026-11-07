import UIKit

/// Builds each scenario state directly, for screenshots and video (`-state <id>`, `-kind channel|group`).
@MainActor
enum StateLauncher {
    static let states = [
        "list.before", "list.menu", "list.after", "list.search", "list.searchEmpty",
        "chat.original", "chat.renamed",
        "profile.original", "profile.more", "profile.renamed",
        "rename.new", "rename.filled", "rename.edit", "rename.cleared",
        "forward.me", "forward.other"
    ]

    static func apply(_ options: LaunchOptions) {
        let app = App.shared
        let store = Store.shared
        let target = Store.targetId
        if options.demo {
            DemoRunner.shared.start()
            return
        }
        let state = options.state
        let renamedStates: Set<String> = ["list.after", "list.search", "list.searchEmpty", "chat.renamed", "profile.renamed", "rename.edit", "rename.cleared", "forward.me", "forward.other"]
        if renamedStates.contains(state) {
            store.setCustomName(target, Store.demoCustomName)
        }
        switch state {
        case "list.menu":
            after(0.3) { app.chatList.openContextMenu(chatId: target) }
        case "list.after":
            after(0.2) { UndoToast.show(text: "Name changed. Only you can see it.", isStatic: true, undo: {
                Store.shared.setCustomName(target, nil)
            }) }
        case "list.search":
            app.chatList.activateSearch(animated: false, query: "beavers")
        case "list.searchEmpty":
            app.chatList.activateSearch(animated: false, query: "beavers winter")
        case "chat.original", "chat.renamed":
            app.push(ChatController(chatId: target), animated: false)
        case "profile.original", "profile.renamed":
            app.push(ChatController(chatId: target), animated: false)
            app.push(PeerInfoController(chatId: target), animated: false)
        case "profile.more":
            app.push(ChatController(chatId: target), animated: false)
            let info = PeerInfoController(chatId: target)
            app.push(info, animated: false)
            after(0.3) { info.openMoreMenu() }
        case "rename.new", "rename.filled", "rename.edit", "rename.cleared":
            app.push(ChatController(chatId: target), animated: false)
            app.push(PeerInfoController(chatId: target), animated: false)
            after(0.1) {
                let rename = RenameController.present(chatId: target, animated: false)
                if state == "rename.filled" {
                    rename.setText(Store.demoCustomName)
                } else if state == "rename.cleared" {
                    rename.setText("")
                }
            }
        case "forward.me":
            app.push(ChatController(chatId: Store.designersId), animated: false)
        case "forward.other":
            app.push(ChatController(chatId: Store.designersId, viewer: .anya), animated: false)
        default:
            break
        }
    }
}

func after(_ seconds: Double, _ fn: @escaping () -> Void) {
    DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: fn)
}
