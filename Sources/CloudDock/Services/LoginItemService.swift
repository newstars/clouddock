import Foundation
import ServiceManagement

protocol LoginItemServicing {
    var isEnabled: Bool { get }
    func setEnabled(_ isEnabled: Bool) -> Bool
}

struct LoginItemService: LoginItemServicing {
    var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    func setEnabled(_ isEnabled: Bool) -> Bool {
        do {
            if isEnabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            }
            return SMAppService.mainApp.status == .enabled
        } catch {
            return SMAppService.mainApp.status == .enabled
        }
    }
}
