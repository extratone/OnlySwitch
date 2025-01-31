//
//  GeneralVM.swift
//  OnlySwitch
//
//  Created by Jacklandrin on 2022/1/5.
//

import Foundation

let menubarIconKey = "menubarIconKey"

class GeneralVM:ObservableObject {
    @Published var cacheSize:String = ""
    @Published var needtoUpdateAlert = false
    @Published var showProgress = false
    @Published var newestVersion = UserDefaults.standard.string(forKey: newestVersionKey) ?? ""
    
    @Published var showMenubarIconPopover = false
    @Published var menubarIcons = ["menubar_0", "menubar_1", "menubar_2", "menubar_3"]
    
    @UserDefaultValue(key: menubarIconKey, defaultValue: "menubar_0")
    var currentMenubarIcon:String
    {
        didSet {
            objectWillChange.send()
            NotificationCenter.default.post(name: changeMenuBarIconNotificationName, object: currentMenubarIcon)
        }
    }
}
