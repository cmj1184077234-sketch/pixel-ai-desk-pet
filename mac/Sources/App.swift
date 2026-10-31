import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    var pet: PetForm?
    let folder: String
    init(folder: String) { self.folder = folder }

    func applicationDidFinishLaunching(_ n: Notification) {
        pet = PetForm(folder: folder, resources: AppPaths.res)
    }

    func applicationWillTerminate(_ n: Notification) {
        pet?.SaveState()
        pet?.SaveDiary()
    }
}
